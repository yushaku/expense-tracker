import Foundation
import Testing

@testable import MonMon

@Suite("Spending trend")
struct SpendingTrendTests {
    private let accountID = UUID()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        on occurredAt: Date
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: "",
            accountID: accountID,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    @Test("A period is drawn one step finer than the unit it is filtered by")
    func unitFollowsTheFilterScope() {
        let anchor = date(2026, 3, 15)

        #expect(SpendingTrend.unit(for: .day(containing: anchor)) == nil)
        #expect(SpendingTrend.unit(for: .month(containing: anchor)) == .day)
        #expect(SpendingTrend.unit(for: .year(containing: anchor)) == .month)
    }

    @Test("A hand-picked range is drawn in days until it grows past a quarter")
    func customRangeSwitchesUnitByLength() {
        let short = TransactionRange.custom(from: date(2026, 3, 1), to: date(2026, 4, 30))
        let long = TransactionRange.custom(from: date(2026, 1, 1), to: date(2026, 9, 30))

        #expect(SpendingTrend.unit(for: short) == .day)
        #expect(SpendingTrend.unit(for: long) == .month)
    }

    @Test("A month draws one point for every day it holds")
    func monthDrawsEveryDay() {
        let points = SpendingTrend.points(
            of: [],
            in: .month(containing: date(2026, 3, 10)),
            today: date(2026, 6, 1)
        )

        #expect(points.count == 31)
        #expect(points.first?.start == date(2026, 3, 1))
        #expect(points.last?.start == date(2026, 3, 31))
    }

    @Test("A year draws one point for every month it holds")
    func yearDrawsEveryMonth() {
        let points = SpendingTrend.points(
            of: [],
            in: .year(containing: date(2026, 3, 10)),
            today: date(2027, 6, 1)
        )

        #expect(points.count == 12)
        #expect(points.first?.start == date(2026, 1, 1))
        #expect(points.last?.start == date(2026, 12, 1))
    }

    @Test("A single day has nothing finer to walk, so it draws nothing")
    func aDayDrawsNothing() {
        let transaction = makeTransaction(kind: .expense, amount: 90_000, on: date(2026, 3, 10))

        let points = SpendingTrend.points(
            of: [transaction],
            in: .day(containing: date(2026, 3, 10)),
            today: date(2026, 6, 1)
        )

        #expect(points.isEmpty)
    }

    @Test("Money out and money in are kept apart, both positive")
    func directionsAreSummedSeparately() {
        let transactions = [
            makeTransaction(kind: .expense, amount: 120_000, on: date(2026, 3, 2)),
            makeTransaction(kind: .expense, amount: 80_000, on: date(2026, 3, 2)),
            makeTransaction(kind: .income, amount: 15_000_000, on: date(2026, 3, 2)),
        ]

        let points = SpendingTrend.points(
            of: transactions,
            in: .month(containing: date(2026, 3, 10)),
            today: date(2026, 6, 1)
        )
        let second = points[1]

        #expect(second.start == date(2026, 3, 2))
        #expect(second.expense == 200_000)
        #expect(second.income == 15_000_000)
    }

    @Test("A day that recorded nothing stays in at zero rather than being dropped")
    func quietDaysAreKeptAtZero() {
        let transaction = makeTransaction(kind: .expense, amount: 60_000, on: date(2026, 3, 4))

        let points = SpendingTrend.points(
            of: [transaction],
            in: .month(containing: date(2026, 3, 10)),
            today: date(2026, 6, 1)
        )

        #expect(points.count == 31)
        #expect(points[2].start == date(2026, 3, 3))
        #expect(points[2].expense == .zero)
        #expect(points[2].income == .zero)
        #expect(points[3].expense == 60_000)
    }

    @Test("A period still running stops at today instead of drawing its rest at zero")
    func aRunningPeriodStopsAtToday() {
        let points = SpendingTrend.points(
            of: [],
            in: .year(containing: date(2026, 3, 10)),
            today: date(2026, 3, 10)
        )

        #expect(points.count == 3)
        #expect(points.last?.start == date(2026, 3, 1))
    }

    @Test("A period already over runs through to its own end")
    func aFinishedPeriodRunsToItsEnd() {
        let points = SpendingTrend.points(
            of: [],
            in: .month(containing: date(2026, 3, 10)),
            today: date(2026, 4, 2)
        )

        #expect(points.count == 31)
        #expect(points.last?.start == date(2026, 3, 31))
    }

    @Test("Money recorded outside the period is not counted")
    func moneyOutsideThePeriodIsIgnored() {
        let transactions = [
            makeTransaction(kind: .expense, amount: 500_000, on: date(2026, 2, 28)),
            makeTransaction(kind: .expense, amount: 700_000, on: date(2026, 4, 1)),
            makeTransaction(kind: .expense, amount: 90_000, on: date(2026, 3, 5)),
        ]

        let points = SpendingTrend.points(
            of: transactions,
            in: .month(containing: date(2026, 3, 10)),
            today: date(2026, 6, 1)
        )
        let total = points.reduce(Decimal.zero) { $0 + $1.expense }

        #expect(total == 90_000)
    }

    @Test("Chart selection snaps to the nearest plotted date")
    func chartSelectionSnapsToNearestDate() {
        let starts = [date(2026, 3, 1), date(2026, 3, 5), date(2026, 3, 10)]

        let selected = TrendChartSelection.nearestDate(
            to: date(2026, 3, 7),
            in: starts
        )

        #expect(selected == date(2026, 3, 5))
    }

    @Test("An equidistant chart selection prefers the earlier plotted date")
    func chartSelectionTiePrefersEarlierDate() {
        let starts = [date(2026, 3, 5), date(2026, 3, 7)]

        let selected = TrendChartSelection.nearestDate(
            to: date(2026, 3, 6),
            in: starts
        )

        #expect(selected == date(2026, 3, 5))
    }

    @Test("Chart selection has no result when the chart has no points")
    func chartSelectionNeedsPoints() {
        #expect(TrendChartSelection.nearestDate(to: .now, in: []) == nil)
    }
}
