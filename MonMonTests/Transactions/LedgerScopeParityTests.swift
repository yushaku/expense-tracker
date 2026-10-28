import Foundation
import SwiftData
import Testing

@testable import MonMon

/// Screens that used to read the whole ledger now fetch a slice of it. Each
/// test here computes a screen's figures both ways, from every row in memory
/// and from the narrowed fetch, and expects the same answer.
@Suite("Narrowed ledger fetches give the same figures")
@MainActor
struct LedgerScopeParityTests {
    private let calendar = TransactionPeriod.calendar
    private let accountID = UUID()
    private let otherAccountID = UUID()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: components) ?? .distantPast
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: MoneyTransaction.self, AccountTransfer.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func transaction(
        _ kind: TransactionKind, _ amount: Decimal, at date: Date,
        accountID: UUID? = nil, categoryID: UUID? = nil, note: String = "",
        sourceRuleID: UUID? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(), kind: kind, amount: amount, occurredAt: date, note: note,
            accountID: accountID ?? self.accountID, categoryID: categoryID,
            sourceRuleID: sourceRuleID, currencyCode: VNDCurrency.code, createdAt: date
        )
    }

    private func transfer(_ amount: Decimal, from source: UUID, to destination: UUID, at date: Date)
        -> AccountTransfer
    {
        AccountTransfer(
            id: UUID(), amount: amount, occurredAt: date, note: "",
            sourceAccountID: source, destinationAccountID: destination,
            currencyCode: VNDCurrency.code, createdAt: date
        )
    }

    private func jar(percent: Decimal, role: BudgetJarRole = .custom) -> BudgetJar {
        BudgetJar(
            id: UUID(), name: "Jar", allocationPercent: percent, role: role,
            symbolName: "tag.fill", colorName: "green",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func salary(day: Date) -> RecurringRule {
        RecurringRule(
            id: UUID(), kind: .income, amount: 30_000_000, note: "Salary",
            accountID: accountID, categoryID: UUID(), currencyCode: VNDCurrency.code,
            frequency: .monthly, interval: 1, anchorDate: day, endDate: nil,
            isPaused: false, lastGeneratedAt: nil, createdAt: day
        )
    }

    /// Rows either side of every edge the budget reads: the month start, the
    /// exclusive month end, and `asOf`.
    private func budgetLedger() -> [MoneyTransaction] {
        [
            transaction(.expense, 100_000, at: date(2026, 7, 31, hour: 23)),
            transaction(.expense, 200_000, at: date(2026, 8, 1)),
            transaction(.income, 7_000_000, at: date(2026, 8, 10)),
            transaction(.expense, 300_000, at: date(2026, 8, 20)),
            transaction(.expense, 400_000, at: date(2026, 8, 20, hour: 1)),
            transaction(.income, 9_000_000, at: date(2026, 8, 25)),
            transaction(.expense, 500_000, at: date(2026, 9, 1)),
            transaction(.income, 1_000_000, at: date(2026, 9, 2)),
        ]
    }

    @Test("Plan's month snapshot and goal capacity match the whole-ledger figures")
    func budgetMonthFetch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let ledger = budgetLedger()
        ledger.forEach(context.insert)
        try context.save()

        let jars = [jar(percent: 60), jar(percent: 30, role: .savings)]
        let rules = [salary(day: date(2026, 1, 25))]
        let asOf = date(2026, 8, 20)

        for visible in [date(2026, 8, 1), date(2026, 7, 1), date(2026, 9, 1)] {
            let fetched = try context.fetch(
                LedgerFetch.transactions(in: .month(containing: visible)))
            func snapshot(_ rows: [MoneyTransaction]) -> BudgetSnapshot {
                BudgetSummary.snapshot(
                    monthContaining: visible, asOf: asOf, jars: jars, categories: [],
                    recurringRules: rules, transactions: rows, savingsDeposits: [],
                    fundHoldings: [])
            }
            #expect(snapshot(fetched) == snapshot(ledger))
        }

        let capacityRows = try context.fetch(
            LedgerFetch.transactions(in: .month(containing: asOf)))
        let fromFetch = BudgetSummary.goalCapacityByJar(
            monthContaining: asOf, asOf: asOf, jars: jars, recurringRules: rules,
            transactions: capacityRows)
        let fromLedger = BudgetSummary.goalCapacityByJar(
            monthContaining: asOf, asOf: asOf, jars: jars, recurringRules: rules,
            transactions: ledger)
        #expect(fromFetch == fromLedger)
        #expect(!fromFetch.isEmpty)
    }

    @Test("An account fetch keeps that account's transactions and both ends of its transfers")
    func accountFetches() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let mine = transaction(.expense, 100_000, at: date(2026, 3, 1))
        let theirs = transaction(.expense, 100_000, at: date(2026, 3, 2), accountID: otherAccountID)
        let out = transfer(10_000, from: accountID, to: otherAccountID, at: date(2026, 3, 3))
        let into = transfer(20_000, from: otherAccountID, to: accountID, at: date(2026, 3, 4))
        let elsewhere = transfer(30_000, from: otherAccountID, to: UUID(), at: date(2026, 3, 5))
        [mine, theirs].forEach(context.insert)
        [out, into, elsewhere].forEach(context.insert)
        try context.save()

        #expect(
            try context.fetch(LedgerFetch.transactions(inAccount: accountID)).map(\.id)
                == [mine.id])
        #expect(
            try context.fetch(LedgerFetch.transfers(touching: accountID)).map(\.id)
                == [into.id, out.id])
    }
}
