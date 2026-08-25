import CoreGraphics
import Testing

@testable import MonMon

@Suite("Month rail swipe")
struct MonthRailSwipeTests {
    @Test("Swiping left advances one month")
    func leftSwipeAdvances() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -120, height: 4)) == 1)
    }

    @Test("Swiping right goes back one month")
    func rightSwipeGoesBack() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: 120, height: -4)) == -1)
    }

    @Test("A short drag does not change the month")
    func shortDragIsIgnored() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: 30, height: 2)) == nil)
    }

    @Test("A mostly vertical drag does not change the month")
    func verticalDragIsIgnored() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -120, height: 140)) == nil)
    }

    @Test("A drag that only leans horizontal does not change the month")
    func shallowlyHorizontalDragIsIgnored() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -120, height: 90)) == nil)
    }

    @Test("A drag no longer than a fully opened row does not change the month")
    func rowSizedDragIsIgnored() {
        let width = TransactionSwipeReveal.actionWidth

        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -width, height: 0)) == nil)
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: width, height: 0)) == nil)
    }
}
