import Foundation
import Testing

@testable import MonMon

@Suite("Transaction range")
struct TransactionRangeTests {
    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    @Test("A day runs from midnight to the next midnight")
    func dayBounds() {
        let range = TransactionRange.day(containing: date(2026, 8, 15, 13, 45))

        #expect(range.start == date(2026, 8, 15))
        #expect(range.end == date(2026, 8, 16))
    }

    @Test("A month runs from its first day to the next month's first day")
    func monthBounds() {
        let range = TransactionRange.month(containing: date(2026, 8, 15))

        #expect(range.start == date(2026, 8, 1))
        #expect(range.end == date(2026, 9, 1))
    }

    @Test("A year runs from January to the next January")
    func yearBounds() {
        let range = TransactionRange.year(containing: date(2026, 8, 15))

        #expect(range.start == date(2026, 1, 1))
        #expect(range.end == date(2027, 1, 1))
    }

    @Test("Membership includes the first instant and excludes the upper bound")
    func membershipBoundaries() {
        let august = TransactionRange.month(containing: date(2026, 8, 15))

        #expect(august.contains(date(2026, 8, 1)))
        #expect(august.contains(date(2026, 8, 31, 23, 59)))
        #expect(!august.contains(date(2026, 9, 1)))
        #expect(!august.contains(date(2026, 7, 31, 23, 59)))
    }

    @Test("A hand-picked range covers both chosen days in full")
    func customCoversBothEnds() {
        let range = TransactionRange.custom(from: date(2026, 8, 10, 9, 0), to: date(2026, 8, 20))

        #expect(range.start == date(2026, 8, 10))
        #expect(range.end == date(2026, 8, 21))
        #expect(range.lastDay == date(2026, 8, 20))
        #expect(range.contains(date(2026, 8, 20, 23, 59)))
    }

    @Test("A hand-picked range orders the pair it is handed")
    func customOrdersItsEnds() {
        let backwards = TransactionRange.custom(from: date(2026, 8, 20), to: date(2026, 8, 10))

        #expect(backwards.start == date(2026, 8, 10))
        #expect(backwards.end == date(2026, 8, 21))
    }

    @Test("A single-day hand-picked range covers that one day")
    func customSingleDay() {
        let range = TransactionRange.custom(from: date(2026, 8, 10), to: date(2026, 8, 10))

        #expect(range.contains(date(2026, 8, 10, 23, 59)))
        #expect(!range.contains(date(2026, 8, 11)))
        #expect(range.title(in: Locale(identifier: "en")) == "Aug 10, 2026")
    }

    @Test("Stepping moves by the scope's own unit and crosses the year")
    func steppingCrossesYear() {
        #expect(
            TransactionRange.day(containing: date(2026, 12, 31)).stepped(by: 1).start
                == date(2027, 1, 1)
        )
        #expect(
            TransactionRange.month(containing: date(2027, 1, 20)).stepped(by: -1).start
                == date(2026, 12, 1)
        )
        #expect(
            TransactionRange.year(containing: date(2026, 5, 4)).stepped(by: 1).start
                == date(2027, 1, 1)
        )
    }

    @Test("A hand-picked range does not step")
    func customDoesNotStep() {
        let range = TransactionRange.custom(from: date(2026, 8, 10), to: date(2026, 8, 20))

        #expect(!range.canStep)
        #expect(range.stepped(by: 1) == range)
    }

    @Test("Re-cutting to another scope keeps the anchor's place")
    func scopingKeepsItsPlace() {
        let march = TransactionRange.month(containing: date(2026, 3, 15))

        #expect(march.scoped(to: .day, anchoredOn: date(2026, 3, 9)).start == date(2026, 3, 9))
        #expect(march.scoped(to: .year, anchoredOn: date(2026, 3, 9)).start == date(2026, 1, 1))
    }

    @Test("Re-cutting to a hand-picked range keeps the days already on show")
    func scopingToCustomKeepsBothEnds() {
        let march = TransactionRange.month(containing: date(2026, 3, 15))
        let custom = march.scoped(to: .custom, anchoredOn: date(2026, 3, 9))

        #expect(custom.scope == .custom)
        #expect(custom.start == march.start)
        #expect(custom.end == march.end)
    }

    @Test("Each scope names itself in English")
    func titlesAreEnglish() {
        let english = Locale(identifier: "en")

        #expect(
            TransactionRange.day(containing: date(2026, 8, 15)).title(in: english)
                == "Aug 15, 2026"
        )
        #expect(
            TransactionRange.month(containing: date(2026, 8, 15)).title(in: english)
                == "August 2026"
        )
        #expect(TransactionRange.year(containing: date(2026, 8, 15)).title(in: english) == "2026")
        #expect(
            TransactionRange.custom(from: date(2026, 8, 10), to: date(2026, 9, 2)).title(
                in: english)
                == "Aug 10, 2026 – Sep 2, 2026"
        )
    }

    @Test("A title asked for in Vietnamese is written in Vietnamese")
    func titlesFollowTheLocale() {
        let vietnamese = Locale(identifier: "vi")

        #expect(
            TransactionRange.day(containing: date(2026, 8, 15)).title(in: vietnamese)
                == "15 thg 8, 2026"
        )
        #expect(
            TransactionRange.month(containing: date(2026, 8, 15)).title(in: vietnamese)
                == "tháng 8 năm 2026"
        )
    }
}
