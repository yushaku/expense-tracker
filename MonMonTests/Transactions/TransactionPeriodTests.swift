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

    @Test("A span of dates lists every year it touches, oldest first")
    func yearsCoverBothEnds() {
        #expect(
            TransactionPeriod.years(from: date(2024, 11, 20), through: date(2026, 2, 3))
                == [date(2024, 1, 1), date(2025, 1, 1), date(2026, 1, 1)]
        )
    }

    @Test("A span of dates lists every day it touches, oldest first")
    func daysCoverBothEnds() {
        #expect(
            TransactionPeriod.days(from: date(2026, 1, 30, 22), through: date(2026, 2, 2))
                == [date(2026, 1, 30), date(2026, 1, 31), date(2026, 2, 1), date(2026, 2, 2)]
        )
    }

    @Test("A year starts at midnight on its first day")
    func startOfYearIsFirstDay() {
        #expect(TransactionPeriod.startOfYear(for: date(2026, 8, 15, 13, 45)) == date(2026, 1, 1))
    }

    @Test("The title names the month and the year in the language it is asked for")
    func titleFollowsTheLocale() {
        let august = date(2026, 8, 15)

        #expect(TransactionPeriod.title(for: august, in: Locale(identifier: "en")) == "August 2026")
        #expect(
            TransactionPeriod.title(for: august, in: Locale(identifier: "vi")) == "tháng 8 năm 2026"
        )
    }
    @Test("Full dates default to zero-padded day/month/year in either language")
    func fullDatesUseNumericFormat() {
        for locale in [Locale(identifier: "en"), Locale(identifier: "vi")] {
            #expect(TransactionPeriod.day(date(2026, 9, 5), in: locale) == "05/09/2026")
        }
    }

    @Test("Each format is exact and zero-padded", arguments: AppDateFormat.allCases)
    func selectableFormats(format: AppDateFormat) {
        let expected: String
        switch format {
        case .dayMonthYear: expected = "05/09/2026"
        case .monthDayYear: expected = "09/05/2026"
        case .yearMonthDay: expected = "2026-09-05"
        }
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "vi_VN")] {
            let value = date(2026, 9, 5, 13, 45)
            #expect(TransactionPeriod.day(value, in: locale, dateFormat: format) == expected)
            let time = TransactionPeriod.format(
                Date.FormatStyle(date: .omitted, time: .shortened), in: locale
            ).format(value)
            #expect(format.dateTime(value, in: locale) == "\(expected) · \(time)")
            #expect(
                TransactionRange.day(containing: value).title(in: locale, dateFormat: format)
                    == expected)
            #expect(
                PeriodRailUnit.day.label(for: value, in: locale, dateFormat: format) == expected)
        }
    }

    @Test("Dates keep the app time zone at a UTC day and year boundary")
    func numericDatesKeepAppCalendar() {
        let instant = Date(timeIntervalSince1970: 1_767_222_000)  // 2025-12-31 18:00 UTC
        #expect(AppDateFormat.dayMonthYear.format(instant) == "01/01/2026")
        #expect(AppDateFormat.yearMonthDay.format(date(2024, 2, 29)) == "2024-02-29")
    }

    @Test("A custom range applies the selected format at both ends")
    func rangeUsesSelectedFormat() {
        let range = TransactionRange.custom(from: date(2025, 12, 31), to: date(2026, 1, 2))
        #expect(
            range.title(in: Locale(identifier: "vi"), dateFormat: .yearMonthDay)
                == "2025-12-31 – 2026-01-02")
        #expect(
            range.phrase(in: Locale(identifier: "en"), dateFormat: .monthDayYear)
                == "between 12/31/2025 and 01/02/2026")
    }

}
