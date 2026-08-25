import CoreGraphics
import Testing

@testable import MonMon

@Suite("Month rail swipe")
struct MonthRailSwipeTests {
    @Test("Swiping left advances one month")
    func leftSwipeAdvances() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -60, height: 4)) == 1)
    }

    @Test("Swiping right goes back one month")
    func rightSwipeGoesBack() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: 60, height: -4)) == -1)
    }

    @Test("A short drag does not change the month")
    func shortDragIsIgnored() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: 30, height: 2)) == nil)
    }

    @Test("A mostly vertical drag does not change the month")
    func verticalDragIsIgnored() {
        #expect(MonthRailSwipe.monthOffset(for: CGSize(width: -60, height: 70)) == nil)
    }
}
