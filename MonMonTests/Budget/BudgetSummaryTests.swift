import Foundation
import Testing

@testable import MonMon

@Suite("Budget summary")
struct BudgetSummaryTests {
    private let calendar = TransactionPeriod.calendar

    @Test("Actual income replaces elapsed forecast while future income stays projected")
    func actualIncomeAndFutureForecastFormTheAvailablePlan() throws {
        let salary = recurringIncome(amount: 30_000_000, day: try date(2026, 8, 25))
        let bonus = recurringIncome(amount: 5_000_000, day: try date(2026, 8, 10))
        let paused = recurringIncome(
            amount: 99_000_000,
            day: try date(2026, 8, 15),
            isPaused: true
        )
        let actualBonus = transaction(
            kind: .income,
            amount: 7_000_000,
            date: try date(2026, 8, 10)
        )

        let snapshot = BudgetSummary.snapshot(
            monthContaining: try date(2026, 8, 1),
            asOf: try date(2026, 8, 20),
            jars: [jar(percent: 100)],
            categories: [],
            recurringRules: [salary, bonus, paused],
            transactions: [actualBonus],
            savingsDeposits: [],
            fundHoldings: []
        )

        #expect(snapshot.plannedIncome == 35_000_000)
        #expect(snapshot.receivedIncome == 7_000_000)
        #expect(snapshot.projectedIncome == 37_000_000)
        #expect(snapshot.rows.count == 1)
        #expect(snapshot.rows.first?.received == 7_000_000)
        #expect(snapshot.rows.first?.remaining == 37_000_000)
    }

    @Test("Spending follows categories while savings and investments use system jars")
    func spendingUsesConfiguredAndSystemJars() throws {
        let necessities = jar(id: UUID(), percent: 50)
        let savings = jar(id: UUID(), percent: 20, role: .savings)
        let investment = jar(id: UUID(), percent: 30, role: .investment)
        let food = category(name: "Food", jarID: necessities.id)
        let unmapped = category(name: "Other", jarID: nil)
        let sourceAccountID = UUID()
        let asOf = try date(2026, 8, 20)

        let snapshot = BudgetSummary.snapshot(
            monthContaining: asOf,
            asOf: asOf,
            jars: [necessities, savings, investment],
            categories: [food, unmapped],
            recurringRules: [
                recurringIncome(amount: 30_000_000, day: try date(2026, 8, 25)),
                recurringIncome(amount: 5_000_000, day: try date(2026, 8, 10)),
            ],
            transactions: [
                transaction(kind: .income, amount: 7_000_000, date: try date(2026, 8, 10)),
                transaction(
                    kind: .expense,
                    amount: 4_000_000,
                    date: try date(2026, 8, 12),
                    categoryID: food.id
                ),
                transaction(
                    kind: .expense,
                    amount: 1_000_000,
                    date: try date(2026, 8, 13),
                    categoryID: unmapped.id
                ),
            ],
            savingsDeposits: [
                SavingsDeposit(
                    id: UUID(),
                    name: "Deposit",
                    principal: 6_000_000,
                    annualInterestRate: 5,
                    termMonths: 6,
                    openedAt: try date(2026, 8, 15),
                    currencyCode: VNDCurrency.code,
                    createdAt: asOf,
                    sourceAccountID: sourceAccountID
                )
            ],
            fundHoldings: [
                FundHolding(
                    id: UUID(),
                    instrumentID: UUID(),
                    units: 100,
                    averageCostPerUnit: 20_000,
                    createdAt: asOf,
                    sourceAccountID: sourceAccountID,
                    purchasedAt: try date(2026, 8, 18)
                )
            ]
        )

        let necessitiesRow = try #require(snapshot.rows.first { $0.jarID == necessities.id })
        let savingsRow = try #require(snapshot.rows.first { $0.jarID == savings.id })
        let investmentRow = try #require(snapshot.rows.first { $0.jarID == investment.id })

        #expect(necessitiesRow.planned == 17_500_000)
        #expect(necessitiesRow.projected == 18_500_000)
        #expect(necessitiesRow.used == 5_000_000)
        #expect(necessitiesRow.remaining == 13_500_000)
        #expect(savingsRow.used == 6_000_000)
        #expect(savingsRow.remaining == 1_400_000)
        #expect(investmentRow.used == 2_000_000)
        #expect(investmentRow.remaining == 9_100_000)
    }

    @Test("Records outside the month or after today do not affect the snapshot")
    func recordsOutsideTheVisibleWindowAreIgnored() throws {
        let asOf = try date(2026, 8, 20)
        let category = category(name: "Food", jarID: BudgetJarSeed.necessitiesID)

        let snapshot = BudgetSummary.snapshot(
            monthContaining: asOf,
            asOf: asOf,
            jars: [jar(id: BudgetJarSeed.necessitiesID, percent: 100)],
            categories: [category],
            recurringRules: [],
            transactions: [
                transaction(
                    kind: .expense,
                    amount: 1_000_000,
                    date: try date(2026, 7, 31),
                    categoryID: category.id
                ),
                transaction(
                    kind: .expense,
                    amount: 2_000_000,
                    date: try date(2026, 8, 21),
                    categoryID: category.id
                ),
            ],
            savingsDeposits: [],
            fundHoldings: []
        )

        #expect(snapshot.rows.count == 1)
        #expect(snapshot.rows.first?.used == .zero)
    }

    @Test("A stale category mapping falls back to an existing jar")
    func staleCategoryMappingFallsBack() throws {
        let necessities = jar(id: BudgetJarSeed.necessitiesID, percent: 100)
        let staleCategory = category(name: "Food", jarID: UUID())
        let asOf = try date(2026, 8, 20)

        let snapshot = BudgetSummary.snapshot(
            monthContaining: asOf,
            asOf: asOf,
            jars: [necessities],
            categories: [staleCategory],
            recurringRules: [],
            transactions: [
                transaction(
                    kind: .expense,
                    amount: 250_000,
                    date: try date(2026, 8, 12),
                    categoryID: staleCategory.id
                )
            ],
            savingsDeposits: [],
            fundHoldings: []
        )

        #expect(snapshot.rows.first?.used == 250_000)
    }

    @Test("A valid transaction override wins and a stale override keeps category routing")
    func transactionOverrideRoutesBeforeCategory() throws {
        let necessities = jar(id: UUID(), percent: 50)
        let play = jar(id: UUID(), percent: 50)
        let food = category(name: "Food", jarID: necessities.id)
        let asOf = try date(2026, 8, 20)
        let tripID = UUID()

        let snapshot = BudgetSummary.snapshot(
            monthContaining: asOf,
            asOf: asOf,
            jars: [necessities, play],
            categories: [food],
            recurringRules: [],
            transactions: [
                transaction(
                    kind: .expense,
                    amount: 300_000,
                    date: try date(2026, 8, 12),
                    categoryID: food.id,
                    tripWorkspaceID: tripID,
                    budgetJarOverrideID: play.id
                ),
                transaction(
                    kind: .expense,
                    amount: 200_000,
                    date: try date(2026, 8, 13),
                    categoryID: food.id,
                    tripWorkspaceID: tripID,
                    budgetJarOverrideID: UUID()
                ),
                transaction(
                    kind: .expense,
                    amount: 100_000,
                    date: try date(2026, 8, 14),
                    categoryID: food.id,
                    budgetJarOverrideID: play.id
                ),
            ],
            savingsDeposits: [],
            fundHoldings: []
        )

        #expect(snapshot.rows.first { $0.jarID == necessities.id }?.used == 300_000)
        #expect(snapshot.rows.first { $0.jarID == play.id }?.used == 300_000)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func jar(
        id: UUID = UUID(),
        percent: Decimal,
        role: BudgetJarRole = .custom
    ) -> BudgetJar {
        BudgetJar(
            id: id,
            name: "Jar",
            allocationPercent: percent,
            role: role,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func category(name: String, jarID: UUID?) -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: name,
            kind: .expense,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            budgetJarID: jarID
        )
    }

    private func recurringIncome(
        amount: Decimal,
        day: Date,
        isPaused: Bool = false
    ) -> RecurringRule {
        RecurringRule(
            id: UUID(),
            kind: .income,
            amount: amount,
            note: "Income",
            accountID: UUID(),
            categoryID: UUID(),
            currencyCode: VNDCurrency.code,
            frequency: .monthly,
            interval: 1,
            anchorDate: day,
            endDate: nil,
            isPaused: isPaused,
            lastGeneratedAt: nil,
            createdAt: day
        )
    }

    private func transaction(
        kind: TransactionKind,
        amount: Decimal,
        date: Date,
        categoryID: UUID? = nil,
        tripWorkspaceID: UUID? = nil,
        budgetJarOverrideID: UUID? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: date,
            note: "",
            accountID: UUID(),
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: date,
            tripWorkspaceID: tripWorkspaceID,
            budgetJarOverrideID: budgetJarOverrideID
        )
    }
}
