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

    @Test("A claimed drag does not change the month, however far it went")
    func claimedDragIsIgnored() {
        #expect(
            MonthRailSwipe.monthOffset(
                for: CGSize(width: -400, height: 0),
                isClaimed: true
            ) == nil
        )
    }

    @Test("An unclaimed drag changes the month")
    func unclaimedDragActs() {
        #expect(
            MonthRailSwipe.monthOffset(
                for: CGSize(width: -400, height: 0),
                isClaimed: false
            ) == 1
        )
    }
}

@Suite("Horizontal swipe arbiter")
struct HorizontalSwipeArbiterTests {
    @Test("Nothing owns a drag until something claims it")
    func startsUnclaimed() {
        #expect(HorizontalSwipeArbiter().isClaimed == false)
    }

    @Test("A claim is held until it is released")
    func claimIsHeldUntilReleased() {
        let arbiter = HorizontalSwipeArbiter()

        arbiter.claim()
        #expect(arbiter.isClaimed)

        arbiter.release()
        #expect(arbiter.isClaimed == false)
    }

    @Test("Claiming twice still takes one release")
    func repeatedClaimsNeedOneRelease() {
        let arbiter = HorizontalSwipeArbiter()

        arbiter.claim()
        arbiter.claim()
        arbiter.release()

        #expect(arbiter.isClaimed == false)
    }
}
