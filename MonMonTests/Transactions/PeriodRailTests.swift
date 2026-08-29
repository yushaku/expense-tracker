import Foundation
import Testing

@testable import MonMon

@Suite("Period rail")
struct PeriodRailTests {
    private let today = Date(timeIntervalSince1970: 1_787_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    @Test("The rail walks in the unit the header is filtering by")
    func unitFollowsTheFilterScope() {
        #expect(PeriodRailUnit(scope: .day) == .day)
        #expect(PeriodRailUnit(scope: .month) == .month)
        #expect(PeriodRailUnit(scope: .year) == .year)
        #expect(PeriodRailUnit(scope: .custom) == .month)
    }

    @Test("A year filter offers years, marking the one on show")
    func yearFilterOffersYears() {
        let rail = PeriodRailPeriods(range: .year(containing: date(2026, 8, 15)), today: today)

        #expect(rail.unit == .year)
        #expect(rail.selection == date(2026, 1, 1))
        #expect(rail.periods.contains(date(2026, 1, 1)))
        #expect(rail.periods.allSatisfy { $0 == TransactionPeriod.startOfYear(for: $0) })
        #expect(rail.periods == rail.periods.sorted())
    }

    @Test("A month filter offers months, as it always has")
    func monthFilterOffersMonths() {
        let rail = PeriodRailPeriods(range: .month(containing: date(2026, 8, 15)), today: today)

        #expect(rail.unit == .month)
        #expect(rail.selection == date(2026, 8, 1))
        #expect(rail.periods.contains(date(2026, 8, 1)))
        #expect(rail.periods.allSatisfy { $0 == TransactionPeriod.startOfMonth(for: $0) })
    }

    @Test("A day filter offers a window of days around the one on show")
    func dayFilterOffersDays() {
        let rail = PeriodRailPeriods(range: .day(containing: date(2026, 8, 15)), today: today)

        #expect(rail.unit == .day)
        #expect(rail.selection == date(2026, 8, 15))
        #expect(rail.periods.first == date(2026, 7, 15))
        #expect(rail.periods.last == date(2026, 9, 15))
        #expect(rail.periods.contains(date(2026, 8, 15)))
    }

    @Test("A hand-picked range walks in months, starting where it starts")
    func customFilterWalksInMonths() {
        let rail = PeriodRailPeriods(
            range: .custom(from: date(2026, 2, 10), to: date(2026, 4, 3)),
            today: today
        )

        #expect(rail.unit == .month)
        #expect(rail.selection == date(2026, 2, 1))
    }

    @Test("A period beyond the calendars' bounds is still on the rail")
    func periodsBeyondTheCalendarBoundsAreKept() {
        let old = PeriodRailPeriods(range: .year(containing: date(1998, 4, 2)), today: today)

        #expect(old.selection == date(1998, 1, 1))
        #expect(old.periods.first == date(1998, 1, 1))
    }

    @Test("Tapping an entry asks for that entry's own period")
    func tappingAnEntryBuildsItsRange() {
        #expect(
            PeriodRailUnit.year.range(containing: date(2026, 8, 15))
                == .year(containing: date(2026, 8, 15))
        )
        #expect(
            PeriodRailUnit.month.range(containing: date(2026, 8, 15))
                == .month(containing: date(2026, 8, 15))
        )
        #expect(
            PeriodRailUnit.day.range(containing: date(2026, 8, 15))
                == .day(containing: date(2026, 8, 15))
        )
    }

    @Test("An entry is written for people and named for tests")
    func entriesAreLabelledByUnit() {
        let english = Locale(identifier: "en")
        let august = date(2026, 8, 15)

        #expect(PeriodRailUnit.year.label(for: august, in: english, today: today) == "2026")
        #expect(PeriodRailUnit.month.label(for: august, in: english, today: today) == "August")
        #expect(PeriodRailUnit.day.label(for: august, in: english, today: today) == "Aug 15")

        #expect(PeriodRailUnit.year.identifier(for: august) == "2026")
        #expect(PeriodRailUnit.month.identifier(for: august) == "2026-08")
        #expect(PeriodRailUnit.day.identifier(for: august) == "2026-08-15")
    }

    @Test("A period outside this year carries the year with it")
    func labelsOutsideThisYearCarryTheYear() {
        let english = Locale(identifier: "en")
        let older = date(2019, 3, 4)

        #expect(PeriodRailUnit.month.label(for: older, in: english, today: today) == "Mar 2019")
        #expect(PeriodRailUnit.day.label(for: older, in: english, today: today) == "Mar 4, 2019")
    }
}
