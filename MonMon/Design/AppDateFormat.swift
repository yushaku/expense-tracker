import Foundation
import SwiftUI

/// An explicit display preference, independent of the interface language.
/// Persistence and bank/API date formats do not use this setting.
enum AppDateFormat: String, CaseIterable, Identifiable {
    case dayMonthYear = "dd/MM/yyyy"
    case monthDayYear = "MM/dd/yyyy"
    case yearMonthDay = "yyyy-MM-dd"  // Keep the stored value compatible with existing preferences.
    case gmt = "gmt"

    static let storageKey = "appDateFormat"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dayMonthYear: "dd/mm/yyyy"
        case .monthDayYear: "mm/dd/yyyy"
        case .yearMonthDay: "yyyy/mm/dd"
        case .gmt: "GMT"
        }
    }

    var style: Date.VerbatimFormatStyle {
        let pattern: Date.FormatString
        switch self {
        case .dayMonthYear:
            pattern = "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits)"
        case .monthDayYear:
            pattern = "\(month: .twoDigits)/\(day: .twoDigits)/\(year: .defaultDigits)"
        case .yearMonthDay:
            pattern = "\(year: .defaultDigits)/\(month: .twoDigits)/\(day: .twoDigits)"
        case .gmt:
            pattern =
                "\(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits) GMT"
        }
        var displayCalendar = TransactionPeriod.calendar
        if self == .gmt { displayCalendar.timeZone = .gmt }
        return Date.VerbatimFormatStyle(
            format: pattern,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: displayCalendar.timeZone,
            calendar: displayCalendar
        )
    }

    func format(_ date: Date) -> String {
        style.format(date)
    }

    /// A history heading names a ledger day, not a timestamp to convert to GMT.
    func calendarDay(_ date: Date) -> String {
        guard self == .gmt else { return format(date) }
        return Date.VerbatimFormatStyle(
            format: "\(day: .twoDigits) \(month: .abbreviated) \(year: .defaultDigits)",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TransactionPeriod.calendar.timeZone,
            calendar: TransactionPeriod.calendar
        ).format(date)
    }

    func dateTime(_ date: Date, in locale: Locale) -> String {
        if self == .gmt { return format(date) }
        let time = TransactionPeriod.format(
            Date.FormatStyle(date: .omitted, time: .shortened), in: locale
        ).format(date)
        return "\(format(date)) · \(time)"
    }
}

extension EnvironmentValues {
    @Entry var appDateFormat = AppDateFormat.dayMonthYear
}
