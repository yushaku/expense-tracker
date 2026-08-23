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

    @Test("The title names the month and the year in English")
    func titleIsEnglish() {
        #expect(TransactionPeriod.title(for: date(2026, 8, 15)) == "August 2026")
    }
}
