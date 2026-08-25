import CoreGraphics
import Testing

@testable import MonMon

@Suite("Transaction report swipe actions")
struct TransactionSwipeRevealTests {
    @Test("Swiping right reveals delete")
    func swipingRightRevealsDelete() {
        #expect(
            TransactionSwipeReveal.resolved(
                after: CGSize(width: 70, height: 8),
                from: .none
            ) == .delete
        )
    }

    @Test("Swiping left reveals edit")
    func swipingLeftRevealsEdit() {
        #expect(
            TransactionSwipeReveal.resolved(
                after: CGSize(width: -70, height: 8),
                from: .none
            ) == .edit
        )
    }

    @Test("Vertical scrolling leaves the current action unchanged")
    func verticalScrollingLeavesRevealUnchanged() {
        #expect(
            TransactionSwipeReveal.resolved(
                after: CGSize(width: 12, height: 80),
                from: .edit
            ) == .edit
        )
    }

    @Test("A short horizontal drag closes the row")
    func shortHorizontalDragClosesRow() {
        #expect(
            TransactionSwipeReveal.resolved(
                after: CGSize(width: 18, height: 2),
                from: .none
            ) == .none
        )
    }
}
