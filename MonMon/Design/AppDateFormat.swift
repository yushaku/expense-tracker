import Foundation
import SwiftUI

/// An explicit display preference, independent of the interface language.
/// Persistence and bank/API date formats do not use this setting.
enum AppDateFormat: String, CaseIterable, Identifiable {
    case dayMonthYear = "dd/MM/yyyy"
    case monthDayYear = "MM/dd/yyyy"
    case yearMonthDay = "yyyy-MM-dd"

    static let storageKey = "appDateFormat"
    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .dayMonthYear: "Day / Month / Year"
        case .monthDayYear: "Month / Day / Year"
        case .yearMonthDay: "Year / Month / Day"
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
            pattern = "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)"
        }
        return Date.VerbatimFormatStyle(
            format: pattern,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TransactionPeriod.calendar.timeZone,
            calendar: TransactionPeriod.calendar
        )
    }

    func format(_ date: Date) -> String {
        style.format(date)
    }

    func dateTime(_ date: Date, in locale: Locale) -> String {
        let time = TransactionPeriod.format(
            Date.FormatStyle(date: .omitted, time: .shortened), in: locale
        ).format(date)
        return "\(format(date)) · \(time)"
    }
}

extension EnvironmentValues {
    @Entry var appDateFormat = AppDateFormat.dayMonthYear
}
