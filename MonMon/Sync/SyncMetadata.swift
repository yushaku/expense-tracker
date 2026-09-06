import Foundation
import SwiftData

/// Local metadata is saved in the same transaction as the financial records it describes.
@Model
final class SyncMetadata {
    var key: String = ""
    var value: Data = Data()

    init(key: String, value: Data = Data()) {
        self.key = key
        self.value = value
    }

    @MainActor
    static func entry(_ key: String, in context: ModelContext) throws -> SyncMetadata? {
        try context.fetch(FetchDescriptor<SyncMetadata>()).first { $0.key == key }
    }

    @MainActor
    static func set(_ key: String, value: Data, in context: ModelContext) throws {
        if let entry = try entry(key, in: context) {
            entry.value = value
        } else {
            context.insert(SyncMetadata(key: key, value: value))
        }
    }
}

@MainActor
enum SeedState {
    static func isInitialized(_ type: String, in context: ModelContext) throws -> Bool {
        try SyncMetadata.entry("seed/" + type, in: context) != nil
    }

    static func mark(_ type: String, in context: ModelContext) throws {
        try SyncMetadata.set("seed/" + type, value: Data(), in: context)
    }

    /// Called before any legacy seeder. Existing financial data means this is an
    /// upgrade, not an empty installation; missing starter rows stay missing.
    static func migrateExistingStore(in context: ModelContext) throws {
        guard try !isInitialized("migration", in: context) else { return }
        let hasData =
            try SyncSnapshot(payload: MonMonBackupService.snapshotPayload(in: context)).records
            .isEmpty == false
        if hasData {
            for type in ["categories", "budgetJars", "defaultBank"] { try mark(type, in: context) }
        }
        try mark("migration", in: context)
        try context.save()
    }
}
