import Foundation
import Testing

@testable import MonMon

@Suite("Recurrence schedule")
struct RecurrenceScheduleTests {
    /// Built through the schedule's own calendar, so a test never depends on the
    /// machine's time zone.
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) throws -> Date {
        try #require(
            RecurrenceSchedule.calendar.date(
                from: DateComponents(year: year, month: month, day: dayOfMonth)
            )
        )
    }

    private func occurrences(
        _ frequency: RecurrenceFrequency,
        interval: Int = 1,
        anchor: Date,
        after: Date? = nil,
        through: Date,
        limit: Int = 400
    ) -> [Date] {
        RecurrenceSchedule.occurrences(
            frequency: frequency,
            interval: interval,
            anchor: anchor,
            after: after,
            through: through,
            limit: limit
        )
    }

    @Test("A daily rule lands on every day from the anchor through the bound")
    func dailyCoversEveryDay() throws {
        let anchor = try day(2026, 3, 1)

        let dates = occurrences(.daily, anchor: anchor, through: try day(2026, 3, 5))

        #expect(
            dates == [
                anchor,
                try day(2026, 3, 2),
                try day(2026, 3, 3),
                try day(2026, 3, 4),
                try day(2026, 3, 5),
            ]
        )
    }

    @Test("An interval of three steps three units at a time")
    func intervalStepsInThrees() throws {
        let anchor = try day(2026, 1, 1)

        let daily = occurrences(.daily, interval: 3, anchor: anchor, through: try day(2026, 1, 10))
        #expect(
            daily == [anchor, try day(2026, 1, 4), try day(2026, 1, 7), try day(2026, 1, 10)]
        )

        let monthly = occurrences(
            .monthly,
            interval: 3,
            anchor: anchor,
            through: try day(2026, 12, 31)
        )
        #expect(
            monthly == [anchor, try day(2026, 4, 1), try day(2026, 7, 1), try day(2026, 10, 1)]
        )
    }

    @Test("A weekly rule keeps the anchor's weekday")
    func weeklyKeepsWeekday() throws {
        let anchor = try day(2026, 3, 4)

        let dates = occurrences(.weekly, anchor: anchor, through: try day(2026, 4, 1))

        #expect(
            dates == [
                anchor,
                try day(2026, 3, 11),
                try day(2026, 3, 18),
                try day(2026, 3, 25),
                try day(2026, 4, 1),
            ]
        )
    }

    @Test("A yearly rule lands on the same date each year")
    func yearlyRepeatsTheDate() throws {
        let anchor = try day(2024, 6, 15)

        let dates = occurrences(.yearly, anchor: anchor, through: try day(2026, 12, 31))

        #expect(dates == [anchor, try day(2025, 6, 15), try day(2026, 6, 15)])
    }

    /// The case that makes anchor-relative arithmetic worth the words: stepping
    /// off the previous date would settle on the 28th for good.
    @Test("A monthly rule anchored on the 31st clamps short months and returns")
    func monthlyAnchoredOnThe31stClampsAndReturns() throws {
        let anchor = try day(2026, 1, 31)

        let dates = occurrences(.monthly, anchor: anchor, through: try day(2026, 5, 31))

        #expect(
            dates == [
                anchor,
                try day(2026, 2, 28),
                try day(2026, 3, 31),
                try day(2026, 4, 30),
                try day(2026, 5, 31),
            ]
        )
    }

    @Test("A monthly rule anchored on the 29th clamps to a leap February")
    func monthlyClampsToLeapFebruary() throws {
        let anchor = try day(2024, 1, 29)

        let dates = occurrences(.monthly, anchor: anchor, through: try day(2024, 3, 31))

        #expect(dates == [anchor, try day(2024, 2, 29), try day(2024, 3, 29)])
    }

    @Test("A monthly rule does not drift over a year")
    func monthlyDoesNotDriftOverAYear() throws {
        let anchor = try day(2026, 1, 31)

        let dates = occurrences(.monthly, anchor: anchor, through: try day(2027, 1, 31))

        let last = try day(2027, 1, 31)

        #expect(dates.count == 13)
        #expect(dates.last == last)
    }

    @Test("The lower bound is exclusive and the upper bound is inclusive")
    func boundsAreHalfOpenAtTheBottom() throws {
        let anchor = try day(2026, 3, 1)

        let dates = occurrences(
            .daily,
            anchor: anchor,
            after: try day(2026, 3, 2),
            through: try day(2026, 3, 4)
        )

        #expect(dates == [try day(2026, 3, 3), try day(2026, 3, 4)])
    }

    @Test("Nothing is returned past the upper bound")
    func nothingLandsPastTheBound() throws {
        let anchor = try day(2026, 3, 1)
        let bound = try day(2026, 3, 3)

        let dates = occurrences(.daily, anchor: anchor, through: bound)

        #expect(dates.count == 3)
        #expect(dates.allSatisfy { $0 <= bound })
    }

    @Test("An anchor after the bound yields nothing")
    func futureAnchorYieldsNothing() throws {
        let dates = occurrences(
            .monthly,
            anchor: try day(2026, 6, 1),
            through: try day(2026, 5, 31)
        )

        #expect(dates.isEmpty)
    }

    @Test("The limit caps how many dates come back")
    func limitCapsTheList() throws {
        let anchor = try day(2020, 1, 1)

        let dates = occurrences(.daily, anchor: anchor, through: try day(2026, 1, 1), limit: 5)

        let last = try day(2020, 1, 5)

        #expect(dates.count == 5)
        #expect(dates.last == last)
    }

    @Test("An interval below one yields nothing")
    func intervalBelowOneYieldsNothing() throws {
        let anchor = try day(2026, 3, 1)

        let bound = try day(2026, 4, 1)

        #expect(occurrences(.daily, interval: 0, anchor: anchor, through: bound).isEmpty)
        #expect(occurrences(.daily, interval: -1, anchor: anchor, through: bound).isEmpty)
    }

    @Test("A time of day on the anchor is normalised away")
    func anchorTimeIsNormalisedToStartOfDay() throws {
        let anchor = try #require(
            RecurrenceSchedule.calendar.date(
                from: DateComponents(year: 2026, month: 3, day: 1, hour: 21, minute: 47)
            )
        )

        let dates = occurrences(.daily, anchor: anchor, through: try day(2026, 3, 2))

        #expect(dates == [try day(2026, 3, 1), try day(2026, 3, 2)])
    }

    @Test("The next occurrence is the first date strictly after the one asked about")
    func nextOccurrenceIsStrictlyAfter() throws {
        let anchor = try day(2026, 1, 31)

        let expected = try day(2026, 3, 31)

        let next = RecurrenceSchedule.nextOccurrence(
            frequency: .monthly,
            interval: 1,
            anchor: anchor,
            after: try day(2026, 2, 28)
        )

        #expect(next == expected)
    }

    @Test("The next occurrence of a future anchor is the anchor itself")
    func nextOccurrenceOfFutureAnchorIsTheAnchor() throws {
        let anchor = try day(2026, 9, 5)

        let next = RecurrenceSchedule.nextOccurrence(
            frequency: .monthly,
            interval: 1,
            anchor: anchor,
            after: try day(2026, 8, 24)
        )

        #expect(next == anchor)
    }
}
