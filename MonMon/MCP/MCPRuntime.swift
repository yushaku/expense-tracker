import Foundation
import SwiftData

#if os(macOS) && !MONMON_MCP_HELPER
    import CoreData
#endif

struct MCPRuntimeConfiguration: Equatable, Sendable {
    let flavour: String
    let serverName: String
    let appGroupIdentifier: String

    static func current(bundle: Bundle = .main) throws -> MCPRuntimeConfiguration {
        guard
            let appGroup = bundle.object(forInfoDictionaryKey: "MonMonAppGroupIdentifier")
                as? String,
            !appGroup.isEmpty
        else {
            throw MCPToolError.storeUnavailable
        }
        #if DEBUG
            let flavour = "dev"
            let serverName = "monmon-dev"
        #else
            let flavour = "release"
            let serverName = "monmon"
        #endif
        return MCPRuntimeConfiguration(
            flavour: flavour,
            serverName: serverName,
            appGroupIdentifier: appGroup
        )
    }

    @MainActor
    func makeSnapshotContainer(allowsSave: Bool) throws -> ModelContainer {
        let schema = Schema([
            MCPStoredSnapshotRecord.self,
            MCPStoredSnapshotMetadata.self,
        ])
        let modelConfiguration = ModelConfiguration(
            "MonMonMCPSnapshot",
            schema: schema,
            allowsSave: allowsSave,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: modelConfiguration)
    }
}

@MainActor
protocol MCPConsentManaging: AnyObject {
    var isAllowed: Bool { get }
    func allow()
    func revoke()
}

final class MCPConsentStore: MCPConsentManaging, @unchecked Sendable {
    static let allowedKey = "MonMonMCPAccessAllowed"

    private let defaults: UserDefaults

    convenience init(configuration: MCPRuntimeConfiguration) throws {
        guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier) else {
            throw MCPToolError.storeUnavailable
        }
        self.init(defaults: defaults)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var isAllowed: Bool {
        defaults.bool(forKey: Self.allowedKey)
    }

    func allow() {
        defaults.set(true, forKey: Self.allowedKey)
    }

    func revoke() {
        defaults.removeObject(forKey: Self.allowedKey)
    }
}

@Model
final class MCPStoredSnapshotRecord {
    @Attribute(.unique) var storageKey: String
    var recordType: String
    var recordID: UUID
    var sortDate: Date
    var fieldsData: Data

    init(record: MCPRecord) throws {
        storageKey = "\(record.recordType):\(record.id.uuidString.lowercased())"
        recordType = record.recordType
        recordID = record.id
        sortDate = record.sortDate
        fieldsData = try JSONEncoder().encode(record.fields)
    }

    func decoded() throws -> MCPRecord {
        let fields: [String: MCPJSONValue]
        do {
            fields = try JSONDecoder().decode([String: MCPJSONValue].self, from: fieldsData)
        } catch {
            throw MCPToolError.decodeFailed
        }
        guard
            fields["recordType"] == .string(recordType),
            fields["id"] == .string(recordID.uuidString.lowercased())
        else {
            throw MCPToolError.decodeFailed
        }
        return MCPRecord(
            recordType: recordType,
            id: recordID,
            sortDate: sortDate,
            fields: fields
        )
    }
}

@Model
final class MCPStoredSnapshotMetadata {
    @Attribute(.unique) var key: String
    var schemaVersion: String
    var generatedAt: Date

    init(schemaVersion: String, generatedAt: Date) {
        key = "current"
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
    }
}

@MainActor
protocol MCPSnapshotReading: AnyObject {
    func generatedAt() throws -> Date?
    func records(for tool: MCPTool) throws -> [MCPRecord]
}

@MainActor
protocol MCPSnapshotExporting: AnyObject {
    func refresh() throws
    func clear() throws
}

/// Opens a fresh read-only SwiftData stack for each request so a long-running
/// AI client sees the latest committed snapshot written by the MonMon process.
@MainActor
final class MCPDiskSnapshotReader: MCPSnapshotReading {
    private let configuration: MCPRuntimeConfiguration

    init(configuration: MCPRuntimeConfiguration) {
        self.configuration = configuration
    }

    func generatedAt() throws -> Date? {
        try database().generatedAt()
    }

    func records(for tool: MCPTool) throws -> [MCPRecord] {
        try database().records(for: tool)
    }

    private func database() throws -> MCPSnapshotDatabase {
        try MCPSnapshotDatabase(configuration: configuration, allowsSave: false)
    }
}

@MainActor
final class MCPSnapshotDatabase: MCPSnapshotReading {
    private let container: ModelContainer

    convenience init(configuration: MCPRuntimeConfiguration, allowsSave: Bool) throws {
        try self.init(container: configuration.makeSnapshotContainer(allowsSave: allowsSave))
    }

    init(container: ModelContainer) {
        self.container = container
    }

    func replace(records: [MCPRecord], generatedAt: Date) throws {
        let stored = try records.map(MCPStoredSnapshotRecord.init)
        guard Set(stored.map(\.storageKey)).count == stored.count else {
            throw MCPToolError.decodeFailed
        }

        let context = makeContext()
        do {
            try context.delete(model: MCPStoredSnapshotRecord.self)
            try context.delete(model: MCPStoredSnapshotMetadata.self)
            stored.forEach(context.insert)
            context.insert(
                MCPStoredSnapshotMetadata(
                    schemaVersion: MCPService.schemaVersion,
                    generatedAt: generatedAt
                ))
            try context.save()
        } catch let error as MCPToolError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw MCPToolError.storeUnavailable
        }
    }

    func clear() throws {
        let context = makeContext()
        do {
            try context.delete(model: MCPStoredSnapshotRecord.self)
            try context.delete(model: MCPStoredSnapshotMetadata.self)
            try context.save()
        } catch {
            context.rollback()
            throw MCPToolError.storeUnavailable
        }
    }

    func generatedAt() throws -> Date? {
        let context = makeContext()
        do {
            var descriptor = FetchDescriptor<MCPStoredSnapshotMetadata>()
            descriptor.fetchLimit = 1
            guard let metadata = try context.fetch(descriptor).first else { return nil }
            guard metadata.schemaVersion == MCPService.schemaVersion else {
                throw MCPToolError.decodeFailed
            }
            return metadata.generatedAt
        } catch let error as MCPToolError {
            throw error
        } catch {
            throw MCPToolError.storeUnavailable
        }
    }

    func records(for tool: MCPTool) throws -> [MCPRecord] {
        guard tool != .dataStatus else { throw MCPToolError.invalidArgument }
        let context = makeContext()
        do {
            var metadataDescriptor = FetchDescriptor<MCPStoredSnapshotMetadata>()
            metadataDescriptor.fetchLimit = 1
            guard let metadata = try context.fetch(metadataDescriptor).first else {
                throw MCPToolError.storeUnavailable
            }
            guard metadata.schemaVersion == MCPService.schemaVersion else {
                throw MCPToolError.decodeFailed
            }
            return try context.fetch(FetchDescriptor<MCPStoredSnapshotRecord>())
                .filter { tool.recordTypes.contains($0.recordType) }
                .map { try $0.decoded() }
        } catch let error as MCPToolError {
            throw error
        } catch {
            throw MCPToolError.storeUnavailable
        }
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}

#if os(macOS) && !MONMON_MCP_HELPER
    @MainActor
    final class MCPAppSnapshotExporter: MCPSnapshotExporting {
        private let sourceContext: ModelContext
        private let database: MCPSnapshotDatabase
        private let consent: any MCPConsentManaging
        private let now: () -> Date
        nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []
        private var refreshTask: Task<Void, Never>?

        init(
            sourceContext: ModelContext,
            database: MCPSnapshotDatabase,
            consent: any MCPConsentManaging,
            now: @escaping () -> Date = Date.init
        ) {
            self.sourceContext = sourceContext
            self.database = database
            self.consent = consent
            self.now = now
        }

        deinit {
            refreshTask?.cancel()
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func startObserving(center: NotificationCenter = .default) {
            guard observers.isEmpty else { return }
            observers = [
                center.addObserver(
                    forName: ModelContext.didSave,
                    object: sourceContext,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.scheduleRefreshIfAllowed()
                    }
                },
                center.addObserver(
                    forName: NSPersistentCloudKitContainer.eventChangedNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard
                        let event = notification.userInfo?[
                            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                        ] as? NSPersistentCloudKitContainer.Event,
                        event.endDate != nil,
                        event.error == nil
                    else { return }
                    MainActor.assumeIsolated {
                        self?.scheduleRefreshIfAllowed()
                    }
                },
            ]
        }

        func refresh() throws {
            let repository = MCPDataRepository(context: sourceContext)
            let records = try MCPTool.snapshotTools.flatMap { try repository.records(for: $0) }
            try database.replace(records: records, generatedAt: now())
        }

        func clear() throws {
            try database.clear()
        }

        func waitForScheduledRefresh() async {
            await refreshTask?.value
        }

        private func scheduleRefreshIfAllowed() {
            refreshTask?.cancel()
            refreshTask = Task { @MainActor [weak self] in
                guard !Task.isCancelled, let self, consent.isAllowed else { return }
                try? refresh()
            }
        }
    }
#endif

enum MCPSnapshotFreshness: String, Codable, Equatable, Sendable {
    case disabled
    case unavailable
    case stale
    case fresh
}

struct MCPSyncMetadata: Codable, Equatable, Sendable {
    let flavour: String
    let accessAllowed: Bool
    let source: String
    let freshness: MCPSnapshotFreshness
    let lastSnapshotAt: Date?

    private enum CodingKeys: String, CodingKey {
        case flavour
        case accessAllowed
        case source
        case freshness
        case lastSnapshotAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flavour, forKey: .flavour)
        try container.encode(accessAllowed, forKey: .accessAllowed)
        try container.encode(source, forKey: .source)
        try container.encode(freshness, forKey: .freshness)
        if let lastSnapshotAt {
            try container.encode(lastSnapshotAt, forKey: .lastSnapshotAt)
        } else {
            try container.encodeNil(forKey: .lastSnapshotAt)
        }
    }
}

@MainActor
protocol MCPDataProviding: AnyObject {
    func status() async -> MCPSyncMetadata
    func records(for tool: MCPTool) async throws -> [MCPRecord]
}

@MainActor
final class MCPSnapshotDataProvider: MCPDataProviding {
    static let defaultFreshnessInterval: TimeInterval = 5 * 60

    private let configuration: MCPRuntimeConfiguration
    private let consent: any MCPConsentManaging
    private let snapshot: any MCPSnapshotReading
    private let freshnessInterval: TimeInterval
    private let now: () -> Date

    init(
        configuration: MCPRuntimeConfiguration,
        consent: any MCPConsentManaging,
        snapshot: any MCPSnapshotReading,
        freshnessInterval: TimeInterval = defaultFreshnessInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.consent = consent
        self.snapshot = snapshot
        self.freshnessInterval = freshnessInterval
        self.now = now
    }

    func status() async -> MCPSyncMetadata {
        guard consent.isAllowed else { return metadata(freshness: .disabled, generatedAt: nil) }
        do {
            guard let generatedAt = try snapshot.generatedAt() else {
                return metadata(freshness: .unavailable, generatedAt: nil)
            }
            let age = max(0, now().timeIntervalSince(generatedAt))
            return metadata(
                freshness: age <= freshnessInterval ? .fresh : .stale,
                generatedAt: generatedAt
            )
        } catch {
            return metadata(freshness: .unavailable, generatedAt: nil)
        }
    }

    func records(for tool: MCPTool) async throws -> [MCPRecord] {
        guard consent.isAllowed else { throw MCPToolError.disabled }
        return try snapshot.records(for: tool)
    }

    private func metadata(
        freshness: MCPSnapshotFreshness,
        generatedAt: Date?
    ) -> MCPSyncMetadata {
        MCPSyncMetadata(
            flavour: configuration.flavour,
            accessAllowed: consent.isAllowed,
            source: "localSnapshot",
            freshness: freshness,
            lastSnapshotAt: generatedAt
        )
    }
}

struct MCPPageEnvelope: Codable, Equatable, Sendable {
    let limit: Int
    let nextCursor: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case limit
        case nextCursor
        case hasMore
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(limit, forKey: .limit)
        if let nextCursor {
            try container.encode(nextCursor, forKey: .nextCursor)
        } else {
            try container.encodeNil(forKey: .nextCursor)
        }
        try container.encode(hasMore, forKey: .hasMore)
    }
}

struct MCPResponseEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: String
    let records: [[String: MCPJSONValue]]
    let page: MCPPageEnvelope
    let sync: MCPSyncMetadata
}

@MainActor
final class MCPService {
    static let schemaVersion = "1.0"

    private let provider: any MCPDataProviding

    init(provider: any MCPDataProviding) {
        self.provider = provider
    }

    func call(tool: MCPTool, arguments: [String: MCPJSONValue]) async throws -> MCPResponseEnvelope
    {
        let query = try MCPQuery.parse(arguments: arguments, for: tool)
        let records: [MCPRecord]
        let sync: MCPSyncMetadata
        if tool == .dataStatus {
            sync = await provider.status()
            let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            records = [
                MCPRecord(
                    recordType: "DataStatus",
                    id: id,
                    sortDate: sync.lastSnapshotAt ?? .distantPast,
                    fields: [
                        "recordType": .string("DataStatus"),
                        "flavour": .string(sync.flavour),
                        "accessAllowed": .bool(sync.accessAllowed),
                        "source": .string(sync.source),
                        "freshness": .string(sync.freshness.rawValue),
                        "lastSnapshotAt": sync.lastSnapshotAt.map {
                            .string(
                                $0.formatted(
                                    Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
                        } ?? .null,
                    ]
                )
            ]
        } else {
            records = try await provider.records(for: tool)
            sync = await provider.status()
        }
        let result = try MCPPaginator.page(records: records, query: query, tool: tool)
        return MCPResponseEnvelope(
            schemaVersion: Self.schemaVersion,
            records: result.records.map(\.fields),
            page: MCPPageEnvelope(
                limit: query.limit,
                nextCursor: result.nextCursor,
                hasMore: result.nextCursor != nil
            ),
            sync: sync
        )
    }
}
