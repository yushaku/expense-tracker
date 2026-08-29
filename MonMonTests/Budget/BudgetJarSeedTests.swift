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
}
