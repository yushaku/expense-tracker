import CoreGraphics
import Testing

@testable import MonMon

@Suite("Transaction swipe actions")
struct TransactionSwipeActionTests {
    private static let commitDistance = TransactionSwipeAction.commitDistance

    @Test("Carrying a row right far enough deletes it on release")
    func farRightSwipeCommitsToDelete() {
        let released = TransactionSwipeMotion()
            .dragging(CGSize(width: Self.commitDistance, height: 8))

        #expect(released.isCommitted)
        #expect(released.committedAction == .delete)
    }

    @Test("Carrying a row left far enough edits it on release")
    func farLeftSwipeCommitsToEdit() {
        let released = TransactionSwipeMotion()
            .dragging(CGSize(width: -Self.commitDistance, height: 8))

        #expect(released.isCommitted)
        #expect(released.committedAction == .edit)
    }

    @Test("A swipe stopped short of the distance does nothing on release")
    func shortSwipeCommitsToNothing() {
        let released = TransactionSwipeMotion()
            .dragging(CGSize(width: Self.commitDistance - 1, height: 8))

        #expect(released.isCommitted == false)
        #expect(released.committedAction == nil)
    }

    @Test("The row follows the finger")
    func rowFollowsTheFinger() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: -70, height: 8))

        #expect(dragging.displayedOffset == -70)
    }

    @Test("What the swipe will do shows from its first point of movement")
    func aimShowsBeforeTheDistanceIsReached() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: 20, height: 2))

        #expect(dragging.aimedAction == .delete)
        #expect(dragging.isCommitted == false)
    }

    @Test("A horizontal drag keeps its axis when the finger moves diagonally")
    func horizontalDragKeepsItsAxis() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: -20, height: 2))
            .dragging(CGSize(width: -60, height: 70))

        #expect(dragging.axis == .horizontal)
        #expect(dragging.displayedOffset == -60)
    }

    @Test("Scrolling leaves the row where it is, however far the finger goes")
    func verticalDragNeverMovesTheRow() {
        let dragging = TransactionSwipeMotion()
            .dragging(CGSize(width: 2, height: 30))
            .dragging(CGSize(width: 200, height: 240))

        #expect(dragging.axis == .vertical)
        #expect(dragging.displayedOffset == 0)
        #expect(dragging.committedAction == nil)
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
}
