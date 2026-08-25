import CoreGraphics
import Testing

@testable import MonMon

@Suite("Transaction report swipe actions")
struct TransactionSwipeRevealTests {
    @Test("Releasing an opening drag settles without returning to the closed position")
    func openingDragSettlesFromFingerPosition() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: 70, height: 8))

        #expect(dragging.displayedOffset == 70)

        let settled = dragging.endingDrag()

        #expect(settled.reveal == .delete)
        #expect(settled.displayedOffset == TransactionSwipeReveal.actionWidth)
    }

    @Test("Releasing a closing drag settles without returning to the open position")
    func closingDragSettlesFromFingerPosition() {
        let dragging = TransactionSwipeMotion(reveal: .edit)
            .dragging(CGSize(width: 70, height: 8))

        #expect(dragging.displayedOffset == -14)

        let settled = dragging.endingDrag()

        #expect(settled.reveal == .none)
        #expect(settled.displayedOffset == 0)
    }

    @Test("A horizontal drag keeps its axis when the finger moves diagonally")
    func horizontalDragKeepsItsAxis() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: -20, height: 2))
            .dragging(CGSize(width: -60, height: 70))

        #expect(dragging.axis == .horizontal)
        #expect(dragging.displayedOffset == -60)
    }

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
