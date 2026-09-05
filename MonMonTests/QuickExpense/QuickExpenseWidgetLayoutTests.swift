import Foundation
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
