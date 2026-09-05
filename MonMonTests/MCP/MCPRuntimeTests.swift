import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("MCP consent and local snapshot runtime", .serialized)
@MainActor
struct MCPRuntimeTests {
    @Test("Consent is disabled by default and can be revoked immediately")
    func consent() {
        let store = MCPConsentStore(defaults: defaults())
        #expect(!store.isAllowed)
        store.allow()
        #expect(store.isAllowed)
        store.revoke()
        #expect(!store.isAllowed)
    }

    @Test("Revoked consent blocks records before reading the snapshot")
    func revokedConsent() async {
        let consent = MCPConsentStore(defaults: defaults())
        let snapshot = FixtureSnapshotReader()
        let provider = MCPSnapshotDataProvider(
            configuration: .test,
            consent: consent,
            snapshot: snapshot
        )

        await #expect(throws: MCPToolError.disabled) {
            _ = try await provider.records(for: .accounts)
        }
        #expect(snapshot.readCount == 0)
        #expect(await provider.status().freshness == .disabled)
    }

    @Test("Snapshot database round-trips stored JSON and selects each tool's record types")
    func databaseRoundTrip() throws {
        let container = try snapshotContainer()
        let database = MCPSnapshotDatabase(container: container)
        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let deposit = record(type: "SavingsDeposit", date: generatedAt)
        let withdrawal = record(
            type: "SavingsWithdrawal",
            date: generatedAt.addingTimeInterval(-1)
        )
        let account = record(type: "CashAccount", date: generatedAt)

        try database.replace(
            records: [deposit, withdrawal, account],
            generatedAt: generatedAt
        )

        #expect(try database.generatedAt() == generatedAt)
        #expect(
            Set(try database.records(for: .savings).map(\.recordType)) == [
                "SavingsDeposit", "SavingsWithdrawal",
            ])
        #expect(try database.records(for: .accounts) == [account])

        try database.clear()
        #expect(try database.generatedAt() == nil)
        #expect(throws: MCPToolError.storeUnavailable) {
            try database.records(for: .accounts)
        }
    }

    @Test("A second read-only container can read the persisted SQLite snapshot")
    func persistentReadOnlySnapshot() throws {
        let schema = Schema([
            MCPStoredSnapshotRecord.self,
            MCPStoredSnapshotMetadata.self,
        ])
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "MCPSnapshotTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "snapshot.sqlite")
        let writerContainer = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                "Snapshot",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        )
        let writer = MCPSnapshotDatabase(container: writerContainer)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let account = record(type: "CashAccount", date: date)
        try writer.replace(records: [account], generatedAt: date)

        let readerContainer = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                "Snapshot",
                schema: schema,
                url: storeURL,
                allowsSave: false,
                cloudKitDatabase: .none
            )
        )
        let reader = MCPSnapshotDatabase(container: readerContainer)

        #expect(try reader.generatedAt() == date)
        #expect(try reader.records(for: .accounts) == [account])
    }

    @Test("Missing snapshots are unavailable and old snapshots are marked stale")
    func freshness() async {
        let consent = MCPConsentStore(defaults: defaults())
        consent.allow()
        let snapshot = FixtureSnapshotReader()
        let now = Date(timeIntervalSince1970: 1_700_001_000)
        let provider = MCPSnapshotDataProvider(
            configuration: .test,
            consent: consent,
            snapshot: snapshot,
            freshnessInterval: 300,
            now: { now }
        )

        #expect(await provider.status().freshness == .unavailable)

        snapshot.snapshotDate = now.addingTimeInterval(-301)
        #expect(await provider.status().freshness == .stale)
        #expect(await provider.status().lastSnapshotAt == snapshot.snapshotDate)

        snapshot.snapshotDate = now.addingTimeInterval(-300)
        #expect(await provider.status().freshness == .fresh)
        #expect(await provider.status().source == "localSnapshot")
    }

    @Test("Data status reports only the local snapshot boundary")
    func dataStatus() async throws {
        let consent = MCPConsentStore(defaults: defaults())
        consent.allow()
        let snapshot = FixtureSnapshotReader()
        let snapshotDate = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.snapshotDate = snapshotDate
        let provider = MCPSnapshotDataProvider(
            configuration: .test,
            consent: consent,
            snapshot: snapshot,
            now: { snapshotDate }
        )

        let response = try await MCPService(provider: provider).call(
            tool: .dataStatus,
            arguments: [:]
        )
        let status = try #require(response.records.first)

        #expect(status["source"] == .string("localSnapshot"))
        #expect(status["lastSnapshotAt"] != nil)
        #expect(status["iCloudAccount"] == nil)
        #expect(snapshot.readCount == 0)

        consent.revoke()
        let disabled = try await MCPService(provider: provider).call(
            tool: .dataStatus,
            arguments: [:]
        )
        let encoded = try JSONEncoder().encode(disabled)
        let json = try JSONDecoder().decode([String: MCPJSONValue].self, from: encoded)
        #expect(json["sync"]?.objectValue?["lastSnapshotAt"] == .null)
    }

    @Test("App exporter writes all local models and refreshes after the source context saves")
    func exporterRefresh() async throws {
        let source = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let snapshot = MCPSnapshotDatabase(container: try snapshotContainer())
        let consent = MCPConsentStore(defaults: defaults())
        consent.allow()
        var currentDate = Date(timeIntervalSince1970: 1_700_000_000)
        let exporter = MCPAppSnapshotExporter(
            sourceContext: source.mainContext,
            database: snapshot,
            consent: consent,
            now: { currentDate }
        )
        exporter.startObserving()

        source.mainContext.insert(
            CashAccount(
                id: UUID(),
                name: "Cash",
                kind: .normal,
                openingBalance: 10,
                currencyCode: "VND",
                createdAt: currentDate
            ))
        try source.mainContext.save()
        await exporter.waitForScheduledRefresh()
        #expect(try snapshot.records(for: .accounts).count == 1)
        #expect(try snapshot.generatedAt() == currentDate)

        currentDate = currentDate.addingTimeInterval(10)
        source.mainContext.insert(
            TransactionCategory(
                id: UUID(),
                name: "Food",
                kind: .expense,
                symbolName: "fork.knife",
                colorName: "orange",
                createdAt: currentDate
            ))
        try source.mainContext.save()
        await exporter.waitForScheduledRefresh()
        #expect(try snapshot.records(for: .categories).count == 1)
        #expect(try snapshot.generatedAt() == currentDate)
    }

    private func snapshotContainer() throws -> ModelContainer {
        let schema = Schema([
            MCPStoredSnapshotRecord.self,
            MCPStoredSnapshotMetadata.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                "Snapshot-\(UUID().uuidString)",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }

    private func record(type: String, date: Date) -> MCPRecord {
        let id = UUID()
        return MCPRecord(
            recordType: type,
            id: id,
            sortDate: date,
            fields: [
                "recordType": .string(type),
                "id": .string(id.uuidString.lowercased()),
                "createdAt": .string(
                    date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
                ),
            ]
        )
    }

    private func defaults() -> UserDefaults {
        let suite = "MCPRuntimeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Could not create isolated test defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

}

@MainActor
private final class FixtureSnapshotReader: MCPSnapshotReading {
    var snapshotDate: Date?
    var readCount = 0

    func generatedAt() throws -> Date? {
        snapshotDate
    }

    func records(for tool: MCPTool) throws -> [MCPRecord] {
        readCount += 1
        return []
    }
}

extension MCPRuntimeConfiguration {
    fileprivate static let test = MCPRuntimeConfiguration(
        flavour: "dev",
        serverName: "monmon-dev",
        appGroupIdentifier: "group.test.monmon"
    )
}
