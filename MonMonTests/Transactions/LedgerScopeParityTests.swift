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

            for jar in jars {
                func activity(_ rows: [MoneyTransaction]) -> [UUID] {
                    BudgetJarActivity.snapshot(
                        for: jar, monthContaining: visible, asOf: asOf, jars: jars,
                        categories: [], transactions: rows, savingsDeposits: [],
                        fundHoldings: []
                    ).transactions.map(\.id)
                }
                #expect(Set(activity(fetched)) == Set(activity(ledger)))
            }
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

    /// The highlights as they were computed before they shared one pass:
    /// a separate search for each window.
    private func separateSearches(
        _ query: TransactionQuery, _ rows: [MoneyTransaction], names: [UUID: String],
        asOf: Date
    ) -> (current: Decimal, previous: Decimal, rhythmCount: Int, rhythmTotal: Decimal)? {
        guard let periods = ReportComparisonPeriods(range: query.range, asOf: asOf) else {
            return nil
        }
        let kind = query.filter.kind ?? .expense
        var current = query
        current.range = periods.current
        current.filter = kind == .income ? .income : .expense
        var previous = current
        previous.range = periods.previous
        var rhythm = current
        rhythm.range = TransactionRange(
            scope: .custom, start: query.range.start,
            end: min(query.range.end, TransactionRange.day(containing: asOf).end))
        func sum(_ q: TransactionQuery) -> [MoneyTransaction] {
            TransactionSearch.results(of: q, transactions: rows, categoryNames: names)
        }
        let rhythmRows = sum(rhythm)
        return (
            sum(current).reduce(0) { $0 + $1.amount },
            sum(previous).reduce(0) { $0 + $1.amount },
            rhythmRows.count, rhythmRows.reduce(0) { $0 + $1.amount }
        )
    }

    @Test("Report highlights match separate searches, from the whole ledger or the fetched span")
    func reportHighlights() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let food = UUID()
        let names = [food: "Ăn uống"]
        var ledger: [MoneyTransaction] = []
        for month in 6...10 {
            for day in [1, 13, 14, 28, 30] {
                guard
                    let at = calendar.date(from: DateComponents(year: 2026, month: month, day: day))
                else { continue }
                ledger.append(
                    transaction(
                        .expense, Decimal(month * 1000 + day), at: at,
                        categoryID: day.isMultiple(of: 2) ? food : nil,
                        note: day == 13 ? "Phở" : ""))
                ledger.append(
                    transaction(.income, Decimal(day * 7), at: at.addingTimeInterval(3600)))
            }
        }
        ledger.forEach(context.insert)
        try context.save()

        let asOf = date(2026, 9, 13, hour: 15)
        var queries: [TransactionQuery] = [
            TransactionQuery(range: .month(containing: asOf)),
            TransactionQuery(range: .month(containing: date(2026, 7, 2))),
            TransactionQuery(range: .year(containing: asOf)),
            TransactionQuery(range: .day(containing: asOf)),
            TransactionQuery(range: .custom(from: date(2026, 8, 10), to: date(2026, 9, 2))),
        ]
        var text = TransactionQuery(range: .month(containing: asOf))
        text.text = "pho"
        var income = TransactionQuery(range: .month(containing: asOf))
        income.filter = .income
        var category = TransactionQuery(range: .month(containing: asOf))
        category.categoryIDs = [food]
        queries += [text, income, category]

        for query in queries {
            let span = ReportContentSpan.fetchedSpan(for: query.range, asOf: asOf)
            let fetched = try context.fetch(LedgerFetch.transactions(in: span))
            let expected = try #require(
                separateSearches(query, ledger, names: names, asOf: asOf))

            for rows in [ledger, fetched] {
                let highlights = try #require(
                    ReportHighlights(
                        query: query, transactions: rows, categoryNames: names,
                        accountNames: [:], asOf: asOf))
                #expect(highlights.current == expected.current)
                #expect(highlights.previous == expected.previous)
                if query.filter.kind != .income {
                    #expect(highlights.spendingRhythm?.count == expected.rhythmCount)
                    #expect(highlights.spendingRhythm?.total == expected.rhythmTotal)
                }
            }

            let fromLedger = try #require(
                ReportHighlights(
                    query: query, transactions: ledger, categoryNames: names,
                    accountNames: [:], asOf: asOf))
            let fromFetch = try #require(
                ReportHighlights(
                    query: query, transactions: fetched, categoryNames: names,
                    accountNames: [:], asOf: asOf))
            #expect(fromLedger.changes.map(\.id) == fromFetch.changes.map(\.id))
            #expect(fromLedger.changes.map(\.delta) == fromFetch.changes.map(\.delta))

            let report = ReportData(
                query: query, transactions: fetched, categoryNames: names, accountNames: [:])
            let whole = ReportData(
                query: query, transactions: ledger, categoryNames: names, accountNames: [:])
            #expect(Set(report.transactions.map(\.id)) == Set(whole.transactions.map(\.id)))
            #expect(report.transactions.count == whole.transactions.count)
        }
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
