import Foundation
import Testing

@testable import MonMon

@Suite("Report highlights")
@MainActor
struct ReportHighlightsTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        guard
            let value = TransactionPeriod.calendar.date(
                from: DateComponents(year: year, month: month, day: day))
        else {
            preconditionFailure("Invalid test date")
        }
        return value
    }

    @Test("Current month compares equal elapsed days and excludes future days")
    func elapsedMonth() throws {
        let now = date(2026, 9, 13)
        let periods = try #require(
            ReportComparisonPeriods(range: .month(containing: now), asOf: now))
        #expect(periods.current == .custom(from: date(2026, 9, 1), to: date(2026, 9, 13)))
        #expect(periods.previous == .custom(from: date(2026, 8, 1), to: date(2026, 8, 13)))
    }

    @Test("Short previous months clamp both ongoing windows; completed months stay whole")
    func shortMonth() throws {
        let range = TransactionRange.month(containing: date(2026, 3, 31))
        let ongoing = try #require(ReportComparisonPeriods(range: range, asOf: date(2026, 3, 31)))
        #expect(ongoing.current.lastDay == date(2026, 3, 28))
        #expect(ongoing.previous.lastDay == date(2026, 2, 28))
        let complete = try #require(ReportComparisonPeriods(range: range, asOf: date(2026, 4, 1)))
        #expect(complete.current.lastDay == date(2026, 3, 31))
        #expect(complete.previous.lastDay == date(2026, 2, 28))
    }

    @Test("Day, year and custom periods have non-overlapping prior windows")
    func otherPeriods() throws {
        let now = date(2026, 9, 13)
        let day = try #require(ReportComparisonPeriods(range: .day(containing: now), asOf: now))
        #expect(day.previous.start == date(2026, 9, 12))
        #expect(day.previous.end == day.current.start)
        let custom = try #require(
            ReportComparisonPeriods(
                range: .custom(from: date(2026, 9, 5), to: date(2026, 9, 10)), asOf: now))
        #expect(custom.previous == .custom(from: date(2026, 8, 30), to: date(2026, 9, 4)))
        let year = try #require(ReportComparisonPeriods(range: .year(containing: now), asOf: now))
        #expect(year.previous.start == date(2025, 1, 1))
        #expect(year.previous.lastDay == date(2025, 9, 13))
        #expect(
            ReportComparisonPeriods(range: .month(containing: date(2026, 10, 1)), asOf: now) == nil)
    }

    @Test("Both periods retain account, category, text and kind filters")
    func filtersAndZeroBaseline() throws {
        let account = UUID(), category = UUID()
        var query = TransactionQuery(range: .month(containing: date(2026, 9, 13)))
        query.accountIDs = [account]
        query.categoryIDs = [category]
        query.text = "lunch"
        let rows = [
            transaction(100, month: 9, account: account, category: category),
            transaction(40, month: 8, account: account, category: category),
            transaction(900, month: 8, account: UUID(), category: category),
            transaction(900, month: 9, account: account, category: UUID()),
            transaction(900, month: 8, account: account, category: category, note: "Dinner"),
            transaction(900, month: 9, account: account, category: category, kind: .income),
        ]
        let highlights = try #require(
            ReportHighlights(
                query: query, transactions: rows,
                categoryNames: [category: "Food"], accountNames: [:], asOf: date(2026, 9, 13)))
        #expect(highlights.current == 100)
        #expect(highlights.previous == 40)
        #expect(highlights.delta == 60)
        #expect(highlights.percentageChange == 1.5)
        #expect(highlights.changes.first?.currentTransactions.count == 1)
        #expect(highlights.changes.first?.previousTransactions.count == 1)
        query.filter = .income
        let income = try #require(
            ReportHighlights(
                query: query, transactions: rows,
                categoryNames: [category: "Food"], accountNames: [:], asOf: date(2026, 9, 13)))
        #expect(income.current == 900)
        #expect(income.previous == 0)
        #expect(income.percentageChange == nil)
    }

    @Test("Ranks the largest absolute changes including prior-only and uncategorized spending")
    func categoryChanges() throws {
        let account = UUID(), food = UUID(), shopping = UUID()
        let rows = [
            transaction(100, month: 9, account: account, category: food),
            transaction(40, month: 8, account: account, category: food),
            transaction(200, month: 8, account: account, category: shopping),
            transaction(20, month: 9, account: account, category: nil),
        ]
        let query = TransactionQuery(range: .month(containing: date(2026, 9, 13)))
        let highlights = try #require(
            ReportHighlights(
                query: query, transactions: rows,
                categoryNames: [food: "Food", shopping: "Shopping"], accountNames: [:],
                asOf: date(2026, 9, 13)))
        #expect(highlights.delta == -120)
        #expect(highlights.changes.map(\.delta) == [-200, 60])
        #expect(highlights.changes.first?.currentTransactions.isEmpty == true)
        let empty = try #require(
            ReportHighlights(
                query: query, transactions: [],
                categoryNames: [:], accountNames: [:], asOf: date(2026, 9, 13)))
        #expect(!empty.hasTransactions)
        #expect(empty.changes.isEmpty)
    }

    private func transaction(
        _ amount: Decimal, month: Int, account: UUID, category: UUID?,
        note: String = "Lunch", kind: TransactionKind = .expense
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(), kind: kind, amount: amount, occurredAt: date(2026, month, 10),
            note: note, accountID: account, categoryID: category, sourceRuleID: nil,
            currencyCode: "VND", createdAt: date(2026, month, 10))
    }
}
