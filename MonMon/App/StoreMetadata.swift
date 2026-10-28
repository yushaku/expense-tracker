import Foundation
import SwiftData

/// Small key/value rows saved in the same transaction as the records they describe.
///
/// The class keeps its original name because SwiftData derives the stored
/// entity name from it: renaming it would orphan every existing store's rows
/// and need a migration plan for no gain. Today it only holds the `seed/*`
/// markers `SeedState` reads; the keys the retired device sync wrote are
/// removed once at launch by `LegacySyncCleanup`.
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
        var descriptor = FetchDescriptor<SyncMetadata>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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

    /// After a restore the store holds exactly what the backup held, so the
    /// starter seeders must not add their rows on top of it.
    static func markAllSeeded(in context: ModelContext) throws {
        for type in ["categories", "budgetJars", "defaultBank", "migration"] {
            try mark(type, in: context)
        }
    }

    /// Called before any legacy seeder. Existing financial data means this is an
    /// upgrade, not an empty installation; missing starter rows stay missing.
    static func migrateExistingStore(in context: ModelContext) throws {
        guard try !isInitialized("migration", in: context) else { return }
        let payload = try MonMonBackupService.snapshotPayload(in: context)
        // Pending captures are drafts, not financial records.
        let hasData = payload.recordCount - payload.pendingCaptures.count > 0
        if hasData {
            for type in ["categories", "budgetJars", "defaultBank"] { try mark(type, in: context) }
        }
        try mark("migration", in: context)
        try context.save()
    }
}
