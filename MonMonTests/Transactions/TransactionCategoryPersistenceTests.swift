import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Transaction category persistence")
@MainActor
struct TransactionCategoryPersistenceTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TransactionCategory.self, MoneyTransaction.self, CashAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTransaction(
        accountID: UUID,
        categoryID: UUID?
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 200_000,
            occurredAt: createdAt,
            note: "",
            accountID: accountID,
            categoryID: categoryID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("An empty store receives the starter categories exactly once")
    func seedingIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        CategorySeed.seedIfEmpty(in: context, createdAt: createdAt)
        let afterFirst = try context.fetch(FetchDescriptor<TransactionCategory>())

        CategorySeed.seedIfEmpty(in: context, createdAt: createdAt)
        let afterSecond = try context.fetch(FetchDescriptor<TransactionCategory>())

        #expect(afterFirst.count == CategorySeed.templates.count)
        #expect(afterSecond.count == CategorySeed.templates.count)
        #expect(afterFirst.contains { $0.name == "Food" && $0.kind == .expense })
        #expect(afterFirst.contains { $0.name == "Salary" && $0.kind == .income })
    }

    @Test("A store that already holds a category is left alone")
    func populatedStoreIsNotSeeded() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(
            TransactionCategory(
                id: UUID(),
                name: "Only one",
                kind: .expense,
                symbolName: CategoryPalette.defaultSymbolName,
                colorName: CategoryPalette.defaultColorName,
                createdAt: createdAt
            )
        )
        try context.save()

        CategorySeed.seedIfEmpty(in: context, createdAt: createdAt)

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        #expect(categories.count == 1)
    }

    @Test("A category round trips through the store")
    func categoryRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let draft = CategoryDraft(
            name: "Coffee",
            kind: .expense,
            symbolName: "cart.fill",
            colorName: "mauve"
        )

        context.insert(try draft.makeCategory(id: UUID(), createdAt: createdAt, existing: []))
        try context.save()

        let stored = try #require(
            try context.fetch(FetchDescriptor<TransactionCategory>()).first
        )
        #expect(stored.name == "Coffee")
        #expect(stored.symbolName == "cart.fill")
        #expect(stored.colorName == "mauve")
    }

    @Test("Reassigning moves every transaction before the category is deleted")
    func reassignThenDeleteMovesEveryTransaction() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let accountID = UUID()

        let food = TransactionCategory(
            id: UUID(),
            name: "Food",
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach",
            createdAt: createdAt
        )
        let shopping = TransactionCategory(
            id: UUID(),
            name: "Shopping",
            kind: .expense,
            symbolName: "cart.fill",
            colorName: "pink",
            createdAt: createdAt
        )
        context.insert(food)
        context.insert(shopping)

        let moved = [
            makeTransaction(accountID: accountID, categoryID: food.id),
            makeTransaction(accountID: accountID, categoryID: food.id),
        ]
        let untouched = makeTransaction(accountID: accountID, categoryID: shopping.id)
        for transaction in moved + [untouched] {
            context.insert(transaction)
        }
        try context.save()

        // What CategoryEditorView.reassignAndDelete performs in one save.
        for transaction in moved {
            transaction.categoryID = shopping.id
        }
        context.delete(food)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(categories.count == 1)
        #expect(categories.first?.name == "Shopping")
        #expect(transactions.count == 3)
        #expect(transactions.allSatisfy { $0.categoryID == shopping.id })
    }
}
