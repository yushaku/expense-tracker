import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Category seed")
@MainActor
struct CategorySeedTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        return ModelContext(container)
    }

    @Test("A store seeded in Vietnamese carries Vietnamese names")
    func seedsInTheChosenLanguage() throws {
        let context = try makeContext()

        CategorySeed.seedIfEmpty(in: context, locale: Locale(identifier: "vi"))

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let names = Set(categories.map(\.name))

        #expect(categories.count == CategorySeed.templates.count)
        #expect(names.contains("Ăn uống"))
        #expect(names.contains("Lương"))
        #expect(!names.contains("Food"))
    }

    /// Identity is what two devices agree on. If it followed the name, a phone
    /// seeded in Vietnamese and a Mac seeded in English would sync to eighteen
    /// categories rather than nine.
    @Test("The same starter category has the same id whichever language seeded it")
    func identityIsIndependentOfLanguage() throws {
        let english = try makeContext()
        let vietnamese = try makeContext()

        CategorySeed.seedIfEmpty(in: english, locale: Locale(identifier: "en"))
        CategorySeed.seedIfEmpty(in: vietnamese, locale: Locale(identifier: "vi"))

        let englishIDs = try Set(english.fetch(FetchDescriptor<TransactionCategory>()).map(\.id))
        let vietnameseIDs = try Set(
            vietnamese.fetch(FetchDescriptor<TransactionCategory>()).map(\.id)
        )

        #expect(englishIDs == vietnameseIDs)
    }

    @Test("The default for a direction is found by identity, not by name")
    func defaultIsFoundByIdentity() throws {
        let context = try makeContext()

        CategorySeed.seedIfEmpty(in: context, locale: Locale(identifier: "vi"))

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let resolved = TransactionDefaults.resolveCategoryID(
            "",
            categories: categories,
            kind: .expense
        )

        #expect(resolved == CategorySeed.defaultID(for: .expense))
    }
}
