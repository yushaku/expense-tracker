import Foundation
import Testing

@testable import MonMon

@Suite("Transaction period")
struct TransactionPeriodTests {
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

    @Test("A month starts at midnight on its first day")
    func startOfMonthIsFirstDay() {
        #expect(TransactionPeriod.startOfMonth(for: date(2026, 8, 15, 13, 45)) == date(2026, 8, 1))
    }

    @Test("A month ends at the first instant of the next month")
    func endOfMonthIsExclusive() {
        #expect(TransactionPeriod.endOfMonth(for: date(2026, 8, 15)) == date(2026, 9, 1))
    }

    @Test("A span of dates lists every month it touches, oldest first")
    func monthsCoverBothEnds() {
        let months = TransactionPeriod.months(
            from: date(2025, 11, 20),
            through: date(2026, 2, 3)
        )

        #expect(
            months == [
                date(2025, 11, 1),
                date(2025, 12, 1),
                date(2026, 1, 1),
                date(2026, 2, 1),
            ]
        )
    }

    @Test("A span inside one month lists that month once")
    func monthsWithinOneMonthCollapse() {
        #expect(
            TransactionPeriod.months(from: date(2026, 8, 2), through: date(2026, 8, 30))
                == [date(2026, 8, 1)]
        )
    }

    @Test("A span that ends before it starts lists nothing")
    func backwardsSpanIsEmpty() {
        let months = TransactionPeriod.months(from: date(2026, 8, 2), through: date(2026, 7, 30))

        #expect(months.isEmpty)
    }

    @Test("The title names the month and the year in the language it is asked for")
    func titleFollowsTheLocale() {
        let august = date(2026, 8, 15)

        #expect(TransactionPeriod.title(for: august, in: Locale(identifier: "en")) == "August 2026")
        #expect(
            TransactionPeriod.title(for: august, in: Locale(identifier: "vi")) == "tháng 8 năm 2026"
        )
    }
}
