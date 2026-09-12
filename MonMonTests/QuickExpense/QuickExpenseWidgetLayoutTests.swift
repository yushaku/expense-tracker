import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Quick expense widget layout")
struct QuickExpenseWidgetLayoutTests {
    /// The change this exists for: medium used to stop at six because that is
    /// what three columns over two rows came to. Four across fits eight.
    @Test("Medium holds eight")
    func mediumHoldsEight() {
        #expect(QuickExpenseWidgetLayout.capacity(.small) == 3)
        #expect(QuickExpenseWidgetLayout.capacity(.medium) == 8)
        #expect(QuickExpenseWidgetLayout.capacity(.large) == 9)
    }

    /// The owner's count and the size's capacity are separate questions. A size
    /// shows as many as it fits and no more; it never asks for more than there
    /// are either.
    @Test("A size shows as many as it fits")
    func aSizeShowsWhatItFits() {
        #expect(QuickExpenseWidgetLayout.visibleCount(configured: 8, size: .medium) == 8)
        #expect(QuickExpenseWidgetLayout.visibleCount(configured: 9, size: .medium) == 8)
        #expect(QuickExpenseWidgetLayout.visibleCount(configured: 2, size: .medium) == 2)
        #expect(QuickExpenseWidgetLayout.visibleCount(configured: 5, size: .small) == 3)
    }

    /// No size may grow a row it has no height for.
    @Test("Medium never needs more than two rows, large never more than three")
    func rowsStayWithinTheSize() {
        for count in QuickExpenseConfiguration.countRange {
            let mediumVisible = QuickExpenseWidgetLayout.visibleCount(
                configured: count,
                size: .medium
            )
            let mediumColumns = QuickExpenseWidgetLayout.columns(
                visible: mediumVisible,
                size: .medium
            )
            #expect(rows(mediumVisible, across: mediumColumns) <= 2, "medium, \(count) presets")

            let largeVisible = QuickExpenseWidgetLayout.visibleCount(
                configured: count,
                size: .large
            )
            let largeColumns = QuickExpenseWidgetLayout.columns(
                visible: largeVisible,
                size: .large
            )
            #expect(rows(largeVisible, across: largeColumns) <= 3, "large, \(count) presets")
        }
    }

    /// A count that fits on one row uses one row, so three presets on a medium
    /// widget sit three across rather than two above one.
    @Test("A single row stays a single row")
    func shortCountsStayOnOneRow() {
        #expect(QuickExpenseWidgetLayout.columns(visible: 3, size: .medium) == 3)
        #expect(QuickExpenseWidgetLayout.columns(visible: 4, size: .medium) == 4)
        #expect(QuickExpenseWidgetLayout.columns(visible: 3, size: .large) == 3)
    }

    @Test("Even counts split evenly")
    func evenCountsSplitEvenly() {
        #expect(QuickExpenseWidgetLayout.columns(visible: 6, size: .medium) == 3)
        #expect(QuickExpenseWidgetLayout.columns(visible: 8, size: .medium) == 4)
        #expect(QuickExpenseWidgetLayout.columns(visible: 9, size: .large) == 3)
    }

    @Test("Small stacks one to a row")
    func smallStacks() {
        for count in 1...3 {
            #expect(QuickExpenseWidgetLayout.columns(visible: count, size: .small) == 1)
        }
    }

    /// A grid needs at least one column, whatever it is handed.
    @Test("An empty or negative count still yields a usable grid")
    func degenerateCountsAreSafe() {
        #expect(QuickExpenseWidgetLayout.columns(visible: 0, size: .medium) >= 1)
        #expect(QuickExpenseWidgetLayout.columns(visible: -1, size: .large) >= 1)
        #expect(QuickExpenseWidgetLayout.visibleCount(configured: -1, size: .medium) == 0)
    }

    private func rows(_ count: Int, across columns: Int) -> Int {
        guard count > 0, columns > 0 else {
            return 0
        }
        return (count + columns - 1) / columns
    }
}

@Suite("Widget today expenses")
@MainActor
struct WidgetTodayExpensesTests {
    @Test("Today excludes income and adjacent days, sorts newest first, totals every expense")
    func todaySnapshot() throws {
        let container = try ModelContainer(
            for: MoneyTransaction.self, TransactionCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let start = TransactionPeriod.calendar.startOfDay(for: now)
        for index in 0..<5 {
            context.insert(
                MoneyTransaction(
                    id: UUID(), kind: .expense, amount: 10_000,
                    occurredAt: start.addingTimeInterval(Double(index)), note: "Expense \(index)",
                    accountID: UUID(), categoryID: nil, sourceRuleID: nil,
                    currencyCode: "VND", createdAt: now))
        }
        for (kind, date) in [
            (TransactionKind.income, now), (.expense, start.addingTimeInterval(-1)),
            (.expense, start.addingTimeInterval(86_400)),
        ] {
            context.insert(
                MoneyTransaction(
                    id: UUID(), kind: kind, amount: 999_000, occurredAt: date, note: "Excluded",
                    accountID: UUID(), categoryID: nil, sourceRuleID: nil,
                    currencyCode: "VND", createdAt: now))
        }
        try context.save()
        let snapshot = try WidgetTodayExpenses.make(in: context, at: now)
        #expect(snapshot.total == 50_000)
        #expect(snapshot.count == 5)
        #expect(snapshot.expenses.map(\.title) == ["Expense 4", "Expense 3", "Expense 2"])
        #expect(snapshot.startOfDay == start)
        let newest = try #require(
            try context.fetch(FetchDescriptor<MoneyTransaction>()).first {
                $0.note == "Expense 4"
            })
        newest.amount = 30_000
        try context.save()
        #expect(try WidgetTodayExpenses.make(in: context, at: now).total == 70_000)
        context.delete(newest)
        try context.save()
        let afterDeletion = try WidgetTodayExpenses.make(in: context, at: now)
        #expect(afterDeletion.count == 4)
        #expect(afterDeletion.total == 40_000)
        #expect(afterDeletion.expenses.first?.title == "Expense 3")

    }

    @Test("Widget link opens expenses without starting capture, including behind the app lock")
    func expensesLink() throws {
        for locked in [false, true] {
            let route = AppRoute()
            let url = try #require(URL(string: "monmon-dev://expenses"))
            #expect(route.receive(url, isLocked: locked))
            #expect(route.expensesRequestID != nil)
            #expect(route.quickCaptureRequestID == nil)
            route.consumeExpenses()
            #expect(route.expensesRequestID == nil)
        }
    }

    @Test("Shared snapshot expires at midnight and reflects replacement after deletion")
    func snapshotStorage() throws {
        let defaults = try #require(UserDefaults(suiteName: "widget-test-\(UUID())"))
        defer { defaults.removeObject(forKey: WidgetTodayExpensesStore.storageKey) }
        let store = WidgetTodayExpensesStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(86_400)
        #expect(store.load(at: start) == nil)
        let snapshot = WidgetTodayExpenses(
            startOfDay: start, endOfDay: end,
            total: 20_000, count: 1,
            expenses: [.init(id: UUID(), title: "Coffee", amount: 20_000)])
        try store.save(snapshot)
        #expect(store.load(at: start)?.total == 20_000)
        #expect(store.load(at: end)?.count == 0)
        try store.save(.init(startOfDay: start, endOfDay: end, total: 0, count: 0, expenses: []))
        #expect(store.load(at: start)?.expenses.isEmpty == true)
    }
}
