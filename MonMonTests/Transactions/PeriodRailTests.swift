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
        let picked = TransactionRange.custom(from: date(2026, 2, 10), to: date(2026, 4, 3))

        #expect(PeriodRailUnit(range: .day(containing: date(2026, 8, 15))) == .day)
        #expect(PeriodRailUnit(range: .month(containing: date(2026, 8, 15))) == .month)
        #expect(PeriodRailUnit(range: .year(containing: date(2026, 8, 15))) == .year)
        #expect(PeriodRailUnit(range: picked) == .custom(picked))
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

    @Test("A hand-picked range is one entry naming both its ends")
    func customFilterIsOneEntry() {
        let picked = TransactionRange.custom(from: date(2026, 2, 10), to: date(2026, 4, 3))
        let rail = PeriodRailPeriods(range: picked, today: today)

        #expect(rail.unit == .custom(picked))
        #expect(rail.periods == [picked.start])
        #expect(rail.selection == picked.start)
        #expect(
            rail.unit.label(for: picked.start, in: Locale(identifier: "en"), today: today)
                == picked.title(in: Locale(identifier: "en"))
        )
        #expect(rail.unit.identifier(for: picked.start) == "custom-2026-02-10-2026-04-03")
    }

    @Test("Tapping a hand-picked range keeps it rather than narrowing it")
    func customFilterSurvivesATap() {
        let picked = TransactionRange.custom(from: date(2026, 2, 10), to: date(2026, 4, 3))

        #expect(PeriodRailUnit.custom(picked).range(containing: picked.start) == picked)
        #expect(!PeriodRailUnit.custom(picked).marksNow(picked.start, now: picked.start))
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
