import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("MCP direct read-only store", .serialized)
@MainActor
struct MCPRuntimeTests {
    private let configuration = MCPRuntimeConfiguration(
        flavour: "dev", serverName: "monmon-dev",
        appGroupIdentifier: "group.test.monmon")

    @Test("Consent blocks access before opening any store, including after revocation")
    func consentBoundary() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let consent = MCPConsentStore(defaults: fixture.defaults)
        var opens = 0
        let provider = MCPDirectDataProvider(
            configuration: configuration, consent: consent,
            open: {
                opens += 1
                return try fixture.reader.open()
            })
        await #expect(throws: MCPToolError.disabled) {
            try await provider.read(tool: .accounts, query: MCPQuery())
        }
        #expect(await provider.status().freshness == .disabled)
        #expect(opens == 0)
        consent.allow()
        _ = try await provider.read(tool: .accounts, query: MCPQuery())
        consent.revoke()
        await #expect(throws: MCPToolError.disabled) {
            try await provider.read(tool: .accounts, query: MCPQuery())
        }
        #expect(opens == 1)
    }

    @Test("Reads saved changes from other contexts without an exporter or running writer")
    func liveReads() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let consent = MCPConsentStore(defaults: fixture.defaults)
        consent.allow()
        let provider = MCPDirectDataProvider(
            configuration: configuration, consent: consent,
            open: { try fixture.reader.open() })
        let service = MCPService(provider: provider)
        let before = try await service.call(tool: .accounts, arguments: [:])
        #expect(before.records.isEmpty)
        let writer = try #require(fixture.writer)
        let context = ModelContext(writer)
        context.autosaveEnabled = false
        let account = CashAccount(
            id: UUID(), name: "Saved", kind: .normal,
            openingBalance: 123, currencyCode: "VND", createdAt: .now)
        context.insert(account)
        #expect(try await service.call(tool: .accounts, arguments: [:]).records.isEmpty)
        try context.save()
        let after = try await service.call(tool: .accounts, arguments: [:])
        #expect(after.records.first?["openingBalance"] == .string("123"))
        #expect(after.sync.source == "localStore")
        #expect(after.sync.lastSnapshotAt == nil)
        #expect(after.sync.readAt != nil)
        account.openingBalance = 456
        try context.save()
        #expect(
            try await service.call(tool: .accounts, arguments: [:]).records.first?["openingBalance"]
                == .string("456"))
    }

    @Test("The store remains readable after the writing container is released and rejects writes")
    func closedAppAndReadOnly() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        fixture.writer = nil
        let container = try fixture.reader.open()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(
            CashAccount(
                id: UUID(), name: "Forbidden", kind: .normal,
                openingBalance: 1, currencyCode: "VND", createdAt: .now))
        #expect(throws: (any Error).self) { try context.save() }
        context.rollback()
        #expect(
            try ModelContext(fixture.reader.open()).fetchCount(FetchDescriptor<CashAccount>()) == 0)
    }

    @Test(
        "Missing or incompatible registration refuses access rather than creating or migrating a store"
    )
    func invalidRegistration() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let data = try #require(fixture.defaults.data(forKey: MCPStoreRegistration.key))
        let descriptor = try JSONDecoder().decode(MCPStoreRegistration.Descriptor.self, from: data)
        let incompatible = MCPStoreRegistration.Descriptor(
            url: descriptor.url,
            schema: Schema([CashAccount.self]), modelHashes: descriptor.modelHashes)
        fixture.defaults.set(
            try JSONEncoder().encode(incompatible), forKey: MCPStoreRegistration.key)
        #expect(throws: MCPToolError.storeUnavailable) { try fixture.reader.open() }
        fixture.defaults.removeObject(forKey: MCPStoreRegistration.key)
        #expect(throws: MCPToolError.storeUnavailable) { try fixture.reader.open() }
        #expect(FileManager.default.fileExists(atPath: descriptor.url.path))
    }

    @Test("Database filters and cursors retain the selected IDs and inclusive date boundaries")
    func filteredPages() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let context = try #require(fixture.writer).mainContext
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var ids: [UUID] = []
        for index in 0..<5 {
            let id = UUID()
            ids.append(id)
            context.insert(
                CashAccount(
                    id: id, name: "Account", kind: .normal,
                    openingBalance: Decimal(index), currencyCode: "VND",
                    createdAt: day.addingTimeInterval(Double(index) * 86400)))
        }
        try context.save()
        let consent = MCPConsentStore(defaults: fixture.defaults)
        consent.allow()
        let service = MCPService(
            provider: MCPDirectDataProvider(
                configuration: configuration,
                consent: consent, open: { try fixture.reader.open() }))
        let arguments: [String: MCPJSONValue] = [
            "limit": .int(1),
            "ids": .array(ids.prefix(4).map { .string($0.uuidString) }),
            "dateFrom": .string(day.addingTimeInterval(86400).formatted(.iso8601)),
            "dateTo": .string(day.addingTimeInterval(3 * 86400).formatted(.iso8601)),
        ]
        var nextArguments = arguments
        var amounts: [String] = []
        repeat {
            let page = try await service.call(tool: .accounts, arguments: nextArguments)
            amounts += page.records.compactMap { $0["openingBalance"]?.stringValue }
            guard let cursor = page.page.nextCursor else { break }
            nextArguments["cursor"] = .string(cursor)
        } while amounts.count < 6
        #expect(amounts == ["3", "2", "1"])
        #expect(
            try await service.call(tool: .accounts, arguments: ["ids": .array([])]).records.isEmpty)
        // Exercise each concrete SwiftData predicate, including composite tools.
        for tool in MCPTool.allCases where tool != .dataStatus {
            _ = try await service.call(tool: tool, arguments: [:])
        }
    }

    @Test("Retiring snapshots removes only the old derived store and registration")
    func legacyCleanup() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let legacy = fixture.directory.appending(path: "MonMonMCPSnapshot.store")
        for suffix in ["", "-wal", "-shm"] {
            try Data("old derived data".utf8).write(to: URL(fileURLWithPath: legacy.path + suffix))
        }
        let container = try #require(fixture.writer)
        let registration = MCPStoreRegistration(
            container: container, defaults: fixture.defaults,
            legacyURL: legacy)
        try registration.register()
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(!FileManager.default.fileExists(atPath: legacy.path + "-wal"))
        #expect(!FileManager.default.fileExists(atPath: legacy.path + "-shm"))
        #expect(try fixture.reader.open().configurations.first?.allowsSave == false)
        try registration.clear()
        #expect(fixture.defaults.data(forKey: MCPStoreRegistration.key) == nil)
        #expect(
            FileManager.default.fileExists(
                atPath: try #require(container.configurations.first).url.path))
    }

    @MainActor
    private final class Fixture {
        let directory: URL
        let suite = "MCPDirectTests.\(UUID())"
        let defaults: UserDefaults
        var writer: ModelContainer?
        var reader: MCPDirectStoreReader { MCPDirectStoreReader(defaults: defaults) }
        init() throws {
            directory = FileManager.default.temporaryDirectory.appending(
                path: "MCPDirectTests-\(UUID())")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            defaults = try #require(UserDefaults(suiteName: suite))
            let schema = Schema(MonMonSchema.models)
            let container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(
                    schema: schema, url: directory.appending(path: "data.store"),
                    cloudKitDatabase: .none))
            writer = container
            try MCPStoreRegistration(container: container, defaults: defaults).register()
        }
        func cleanUp() {
            writer = nil
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
