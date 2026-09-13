import CoreData
import Foundation
import SwiftData

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
        defaults.removeObject(forKey: MCPResearchService.writingAllowedKey)
    }
}

/// Only the store location and schema are registered; no financial records are copied.
@MainActor
protocol MCPStoreRegistering: AnyObject {
    func register() throws
    func clear() throws
}

@MainActor
final class MCPStoreRegistration: MCPStoreRegistering {
    static let key = "MonMonMCPDirectStore"
    struct Descriptor: Codable {
        let url: URL
        let schema: Schema
        let modelHashes: [String: Data]
    }
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let legacyURL: URL?

    init(container: ModelContainer, defaults: UserDefaults, legacyURL: URL? = nil) {
        self.container = container
        self.defaults = defaults
        self.legacyURL = legacyURL
    }

    func register() throws {
        try removeLegacySnapshot()
        guard let configuration = container.configurations.first,
            !configuration.isStoredInMemoryOnly
        else { throw MCPToolError.storeUnavailable }
        let url = configuration.url
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: [NSReadOnlyPersistentStoreOption: true])
        guard let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data] else {
            throw MCPToolError.storeUnavailable
        }
        defaults.set(
            try JSONEncoder().encode(
                Descriptor(
                    url: url, schema: container.schema, modelHashes: hashes)), forKey: Self.key)
    }

    func clear() throws {
        defaults.removeObject(forKey: Self.key)
        try removeLegacySnapshot()
    }

    private func removeLegacySnapshot() throws {
        guard let legacyURL else { return }
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: legacyURL.path + suffix)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}

@MainActor
final class MCPDirectStoreReader {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }

    func open() throws -> ModelContainer {
        guard let data = defaults.data(forKey: MCPStoreRegistration.key),
            let descriptor = try? JSONDecoder().decode(
                MCPStoreRegistration.Descriptor.self, from: data),
            descriptor.url.isFileURL,
            FileManager.default.fileExists(atPath: descriptor.url.path)
        else { throw MCPToolError.storeUnavailable }
        let schema = Schema(MonMonSchema.models)
        guard descriptor.schema == schema else { throw MCPToolError.storeUnavailable }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: descriptor.url,
            options: [NSReadOnlyPersistentStoreOption: true])
        guard let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data],
            hashes == descriptor.modelHashes
        else { throw MCPToolError.storeUnavailable }
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                schema: schema, url: descriptor.url, allowsSave: false, cloudKitDatabase: .none))
    }
}

enum MCPDataFreshness: String, Codable, Equatable, Sendable {
    case disabled, unavailable, fresh
}

struct MCPSyncMetadata: Codable, Equatable, Sendable {
    let flavour: String
    let accessAllowed: Bool
    let source: String
    let freshness: MCPDataFreshness
    let readAt: Date?
}

struct MCPDataRead {
    let records: [MCPRecord]
    let metadata: MCPSyncMetadata
}

@MainActor
protocol MCPDataProviding: AnyObject {
    func status() async -> MCPSyncMetadata
    func read(tool: MCPTool, query: MCPQuery) async throws -> MCPDataRead
}

@MainActor
final class MCPDirectDataProvider: MCPDataProviding {
    private let configuration: MCPRuntimeConfiguration
    private let consent: any MCPConsentManaging
    private let open: () throws -> ModelContainer

    init(
        configuration: MCPRuntimeConfiguration, consent: any MCPConsentManaging,
        open: @escaping () throws -> ModelContainer
    ) {
        self.configuration = configuration
        self.consent = consent
        self.open = open
    }

    func status() async -> MCPSyncMetadata {
        guard consent.isAllowed else { return metadata(.disabled) }
        do {
            _ = try open()
            return metadata(.fresh, readAt: .now)
        } catch { return metadata(.unavailable) }
    }

    func read(tool: MCPTool, query: MCPQuery) async throws -> MCPDataRead {
        guard consent.isAllowed else { throw MCPToolError.disabled }
        do {
            let container = try open()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let records = try MCPDataRepository(context: context).records(for: tool, query: query)
            guard consent.isAllowed else { throw MCPToolError.disabled }
            return MCPDataRead(records: records, metadata: metadata(.fresh, readAt: .now))
        } catch let error as MCPToolError { throw error } catch {
            throw MCPToolError.storeUnavailable
        }
    }

    private func metadata(_ freshness: MCPDataFreshness, readAt: Date? = nil) -> MCPSyncMetadata {
        MCPSyncMetadata(
            flavour: configuration.flavour, accessAllowed: consent.isAllowed,
            source: "localStore", freshness: freshness, readAt: readAt)
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
    let query: MCPQueryMetadata
    let sync: MCPSyncMetadata
}

struct MCPQueryMetadata: Codable, Equatable, Sendable {
    let sort: String
    let dateRange: String
    let dateFilterFields: [String: String]
}

@MainActor
final class MCPService {
    static let schemaVersion = "3.0"

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
                    sortDate: sync.readAt ?? .distantPast,
                    fields: [
                        "recordType": .string("DataStatus"),
                        "flavour": .string(sync.flavour),
                        "accessAllowed": .bool(sync.accessAllowed),
                        "source": .string(sync.source),
                        "freshness": .string(sync.freshness.rawValue),
                        "readAt": sync.readAt.map {
                            .string(
                                $0.formatted(
                                    Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
                        } ?? .null,
                    ]
                )
            ]
        } else {
            let read = try await provider.read(tool: tool, query: query)
            records = read.records
            sync = read.metadata
        }
        let queryMetadata = MCPQueryMetadata(
            sort: tool.sortDescription,
            dateRange: tool.dateFilterFields.isEmpty
                ? "not supported" : "dateFrom inclusive, dateTo exclusive",
            dateFilterFields: tool.dateFilterFields)
        if tool == .summary || tool == .portfolio {
            return MCPResponseEnvelope(
                schemaVersion: Self.schemaVersion,
                records: records.map(\.fields),
                page: MCPPageEnvelope(limit: 1, nextCursor: nil, hasMore: false),
                query: queryMetadata, sync: sync)
        }
        let result = try MCPPaginator.page(records: records, query: query, tool: tool)
        return MCPResponseEnvelope(
            schemaVersion: Self.schemaVersion,
            records: result.records.map(\.fields),
            page: MCPPageEnvelope(
                limit: query.limit,
                nextCursor: result.nextCursor,
                hasMore: result.nextCursor != nil
            ), query: queryMetadata,
            sync: sync
        )
    }
}
