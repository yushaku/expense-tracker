import Foundation
import Testing

@testable import MonMon

@Suite("Trading calendar")
struct TradingCalendarTests {
    /// Built in the calendar the app shares, so these read as Ho Chi Minh City
    /// wall-clock times rather than whatever the machine is set to.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return TradingCalendar.calendar.date(from: components) ?? .distantPast
    }

    private func startOfDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TradingCalendar.calendar.startOfDay(for: date(year, month, day))
    }

    // 2026-08-21 is a Friday; 22 and 23 are the weekend; 24 is a Monday.

    @Test("Weekdays trade and the weekend does not")
    func weekendIsNotATradingDay() {
        #expect(TradingCalendar.isTradingDay(date(2026, 8, 21)))
        #expect(!TradingCalendar.isTradingDay(date(2026, 8, 22)))
        #expect(!TradingCalendar.isTradingDay(date(2026, 8, 23)))
        #expect(TradingCalendar.isTradingDay(date(2026, 8, 24)))
    }

    @Test("Before the close, the last completed day is the previous weekday")
    func beforeCloseLastDayIsYesterday() {
        #expect(
            TradingCalendar.lastCompletedTradingDay(asOf: date(2026, 8, 21, 14))
                == startOfDay(2026, 8, 20)
        )
    }

    @Test("From the close, the last completed day is today")
    func fromCloseLastDayIsToday() {
        #expect(
            TradingCalendar.lastCompletedTradingDay(asOf: date(2026, 8, 21, 15))
                == startOfDay(2026, 8, 21)
        )
    }

    @Test("On the weekend, the last completed day is Friday")
    func weekendLooksBackToFriday() {
        #expect(
            TradingCalendar.lastCompletedTradingDay(asOf: date(2026, 8, 23, 20))
                == startOfDay(2026, 8, 21)
        )
    }

    @Test("Monday morning looks back to Friday, not to Sunday")
    func mondayMorningLooksBackToFriday() {
        #expect(
            TradingCalendar.lastCompletedTradingDay(asOf: date(2026, 8, 24, 9))
                == startOfDay(2026, 8, 21)
        )
    }

    @Test("Stepping back crosses a year boundary")
    func steppingCrossesAYear() {
        // 2027-01-01 is a Friday, so the weekday before it is 2026-12-31.
        #expect(
            TradingCalendar.lastCompletedTradingDay(asOf: date(2027, 1, 1, 9))
                == startOfDay(2026, 12, 31)
        )
    }

    /// An ETF is priced by a close, so anything older than the last close is
    /// stale. A fund's NAV arrives at T+1, so it gets one extra day.
    @Test("An ETF is stale one trading day after the close it carries")
    func etfGoesStaleImmediately() {
        let asOf = date(2026, 8, 24, 16)

        #expect(
            !TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 24),
                kind: .etf,
                asOf: asOf
            )
        )
        #expect(
            TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 21),
                kind: .etf,
                asOf: asOf
            )
        )
    }

    @Test("A fund gets one extra day, because its NAV publishes at T+1")
    func fundGetsATPlusOneGrace() {
        let asOf = date(2026, 8, 24, 16)

        // The day before last is current for a fund and stale for an ETF.
        #expect(
            !TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 21),
                kind: .fund,
                asOf: asOf
            )
        )
        #expect(
            TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 20),
                kind: .fund,
                asOf: asOf
            )
        )
    }

    @Test("Gold goes stale at midnight even on Sunday")
    func goldGoesStaleEveryDay() {
        let sundayMorning = date(2026, 8, 23, 9)

        #expect(
            TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 22),
                kind: .gold,
                asOf: sundayMorning
            )
        )
        #expect(
            !TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 21),
                kind: .etf,
                asOf: sundayMorning
            )
        )
        #expect(
            !TradingCalendar.isStale(
                priceAsOf: startOfDay(2026, 8, 23),
                kind: .gold,
                asOf: sundayMorning
            )
        )
    }

    /// Holidays are deliberately not modelled. Reporting Tết as stale is honest
    /// about what the app knows; a hardcoded table would quietly go wrong later.
    @Test("A holiday reads as stale rather than being modelled")
    func holidaysAreReportedStale() {
        // 2027-02-08 is a Monday inside the Tết break.
        #expect(
            TradingCalendar.isStale(
                priceAsOf: startOfDay(2027, 2, 5),
                kind: .etf,
                asOf: date(2027, 2, 8, 16)
            )
        )
    }

    /// Crypto trades without a session, so its freshness is a clock question,
    /// not a calendar one. A price minutes old is current; the same price an
    /// hour later is not, whatever day of the week it is.
    @Test("A crypto price inside the stale window is current")
    func cryptoInsideWindowIsCurrent() {
        let asOf = date(2026, 8, 23, 9)

        #expect(
            !TradingCalendar.isStale(
                priceAsOf: asOf.addingTimeInterval(-5 * 60),
                kind: .crypto,
                asOf: asOf
            )
        )
    }

    @Test("A crypto price older than the stale window is stale, even on a Sunday")
    func cryptoOutsideWindowIsStale() {
        // 2026-08-23 is a Sunday, when no other kind expects a new price.
        let sundayMorning = date(2026, 8, 23, 9)

        #expect(
            TradingCalendar.isStale(
                priceAsOf: sundayMorning.addingTimeInterval(-20 * 60),
                kind: .crypto,
                asOf: sundayMorning
            )
        )
    }

    @Test("Crypto staleness ignores the start of the day")
    func cryptoDoesNotResetAtMidnight() {
        // Priced at 00:05 and read at 23:00: the same calendar day, and stale.
        #expect(
            TradingCalendar.isStale(
                priceAsOf: date(2026, 8, 24).addingTimeInterval(5 * 60),
                kind: .crypto,
                asOf: date(2026, 8, 24, 23)
            )
        )
    }
}
