import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Budget jar seed")
struct BudgetJarSeedTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("An empty store gains the standard six jars once")
    func emptyStoreGainsSixJarsOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext

        BudgetJarSeed.seedIfNeeded(
            in: context,
            createdAt: referenceDate,
            locale: Locale(identifier: "en")
        )
        BudgetJarSeed.seedIfNeeded(
            in: context,
            createdAt: referenceDate,
            locale: Locale(identifier: "en")
        )

        let jars = try context.fetch(FetchDescriptor<BudgetJar>())
            .sorted { $0.createdAt < $1.createdAt }

        #expect(jars.count == 6)
        #expect(
            jars.map(\.name) == [
                "Necessities", "Investment", "Education", "Savings", "Play", "Giving",
            ])
        #expect(jars.map(\.allocationPercent) == [55, 10, 10, 10, 10, 5])
        #expect(jars.reduce(Decimal.zero) { $0 + $1.allocationPercent } == 100)
        #expect(jars.first { $0.id == BudgetJarSeed.investmentID }?.role == .investment)
        #expect(jars.first { $0.id == BudgetJarSeed.savingsID }?.role == .savings)
    }

    @Test("Seeded expense categories receive useful default jars")
    func seededCategoriesReceiveDefaultJars() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let categories = CategorySeed.makeCategories(
            createdAt: referenceDate,
            locale: Locale(identifier: "en")
        )
        categories.forEach(context.insert)

        BudgetJarSeed.seedIfNeeded(
            in: context,
            createdAt: referenceDate,
            locale: Locale(identifier: "en")
        )

        let food = try #require(categories.first { $0.name == "Food" })
        let entertainment = try #require(categories.first { $0.name == "Entertainment" })
        let salary = try #require(categories.first { $0.name == "Salary" })

        #expect(food.budgetJarID == BudgetJarSeed.necessitiesID)
        #expect(entertainment.budgetJarID == BudgetJarSeed.playID)
        #expect(salary.budgetJarID == nil)
    }

    @Test("Entertainment maps to Play regardless of the seeded language")
    func entertainmentMappingUsesStableIdentity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let categories = CategorySeed.makeCategories(
            createdAt: referenceDate,
            locale: Locale(identifier: "vi")
        )
        categories.forEach(context.insert)

        BudgetJarSeed.seedIfNeeded(
            in: context,
            createdAt: referenceDate,
            locale: Locale(identifier: "en")
        )

        let entertainment = try #require(
            categories.first { $0.id == CategorySeed.entertainmentID }
        )
        #expect(entertainment.name == "Giải trí")
        #expect(entertainment.budgetJarID == BudgetJarSeed.playID)
    }

    @Test("System jars cannot be deleted")
    func systemJarsCannotBeDeleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let savings = BudgetJar(
            id: UUID(),
            name: "Savings",
            allocationPercent: 10,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: referenceDate
        )
        context.insert(savings)
        try context.save()

        #expect(throws: BudgetJarStoreError.protectedJar) {
            try BudgetJarStore.delete(
                savings,
                jars: [savings],
                categories: [],
                in: context
            )
        }
        #expect(try context.fetchCount(FetchDescriptor<BudgetJar>()) == 1)
    }

    @Test("Deleting a custom jar reassigns its categories")
    func deletingCustomJarReassignsCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let necessities = BudgetJar(
            id: BudgetJarSeed.necessitiesID,
            name: "Necessities",
            allocationPercent: 55,
            role: .custom,
            symbolName: "house.fill",
            colorName: "blue",
            createdAt: referenceDate
        )
        let play = BudgetJar(
            id: UUID(),
            name: "Play",
            allocationPercent: 10,
            role: .custom,
            symbolName: "gamecontroller.fill",
            colorName: "pink",
            createdAt: referenceDate.addingTimeInterval(1)
        )
        let entertainment = TransactionCategory(
            id: UUID(),
            name: "Entertainment",
            kind: .expense,
            symbolName: "gamecontroller.fill",
            colorName: "pink",
            createdAt: referenceDate,
            budgetJarID: play.id
        )
        [necessities, play].forEach(context.insert)
        context.insert(entertainment)
        try context.save()

        try BudgetJarStore.delete(
            play,
            jars: [necessities, play],
            categories: [entertainment],
            in: context
        )

        #expect(entertainment.budgetJarID == necessities.id)
        #expect(try context.fetchCount(FetchDescriptor<BudgetJar>()) == 1)
    }
}
