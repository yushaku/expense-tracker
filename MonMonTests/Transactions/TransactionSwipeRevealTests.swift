import CoreGraphics
import Testing

@testable import MonMon

@Suite("Transaction report swipe actions")
struct TransactionSwipeRevealTests {
    @Test("A stationary touch resolves only as a tap")
    func stationaryTouchResolvesAsTap() {
        #expect(
            TransactionRowGestureIntent.resolved(
                after: CGSize(width: 2, height: 3)
            ) == .tap
        )
    }

    @Test("A horizontal drag resolves only as a swipe")
    func horizontalDragResolvesAsSwipe() {
        #expect(
            TransactionRowGestureIntent.resolved(
                after: CGSize(width: -70, height: 8)
            ) == .swipe
        )
    }

    @Test("A vertical drag resolves only as scrolling")
    func verticalDragResolvesAsScrolling() {
        #expect(
            TransactionRowGestureIntent.resolved(
                after: CGSize(width: 8, height: 70)
            ) == .scroll
        )
    }

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
