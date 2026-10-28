import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Legacy sync cleanup")
@MainActor
struct LegacySyncCleanupTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "legacy-sync-cleanup-\(UUID())"))
    }

    private func keys(in container: ModelContainer) throws -> [String] {
        try ModelContext(container).fetch(FetchDescriptor<SyncMetadata>()).map(\.key).sorted()
    }

    @Test("Removes sync rows and keeps seed markers and financial data")
    func removesSyncRowsOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SyncMetadata(key: "sync/state", value: Data("{}".utf8)))
        context.insert(SyncMetadata(key: "sync/other", value: Data()))
        CategorySeed.seedIfEmpty(in: context)
        try SeedState.mark("migration", in: context)
        try context.save()
        let categories = try context.fetchCount(FetchDescriptor<TransactionCategory>())
        #expect(categories > 0)
        let defaults = try makeDefaults()

        let report = try LegacySyncCleanup.run(
            in: context, defaults: defaults, deleteKeychainItems: { true })

        #expect(report.deletedMetadataRows == 2)
        #expect(try keys(in: container) == ["seed/categories", "seed/migration"])
        #expect(try SeedState.isInitialized("categories", in: ModelContext(container)))
        #expect(
            try ModelContext(container).fetchCount(FetchDescriptor<TransactionCategory>())
                == categories)
    }

    @Test("Runs once: a second launch touches neither the store nor Keychain")
    func runsOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(SyncMetadata(key: "sync/state", value: Data()))
        try SeedState.mark("budgetJars", in: context)
        try context.save()
        let defaults = try makeDefaults()
        var keychainCalls = 0
        let deleteKeychain = {
            keychainCalls += 1
            return true
        }

        let first = try LegacySyncCleanup.run(
            in: context, defaults: defaults, deleteKeychainItems: deleteKeychain)
        let second = try LegacySyncCleanup.run(
            in: context, defaults: defaults, deleteKeychainItems: deleteKeychain)

        #expect(first == .init(deletedMetadataRows: 1, cleanedKeychain: true))
        #expect(second == .init())
        #expect(keychainCalls == 1)
        #expect(!context.hasChanges)
        #expect(try keys(in: container) == ["seed/budgetJars"])
    }

    @Test("A Keychain sweep that fails is retried on the next launch")
    func retriesKeychainUntilItSucceeds() throws {
        let container = try makeContainer()
        let defaults = try makeDefaults()

        let failed = try LegacySyncCleanup.run(
            in: container.mainContext, defaults: defaults, deleteKeychainItems: { false })
        let retried = try LegacySyncCleanup.run(
            in: container.mainContext, defaults: defaults, deleteKeychainItems: { true })

        #expect(!failed.cleanedKeychain)
        #expect(retried.cleanedKeychain)
        #expect(defaults.bool(forKey: LegacySyncCleanup.keychainCleanedKey))
    }
}
