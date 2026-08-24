import Foundation

/// Calendar-month maths, and the calendar every other date type in the app
/// borrows. Every function takes the dates it needs and nothing reads the clock,
/// so tests stay deterministic. The calendar is shared with `SavingsInterest`
/// rather than redefined, so no module depends on the machine's locale or time
/// zone. `TransactionRange` builds the wider periods the spending list offers on
/// top of this.
enum TransactionPeriod {
    static var calendar: Calendar {
        SavingsInterest.calendar
    }

    /// A date style that writes dates in `locale` but measures them with the
    /// app's own calendar and time zone. What a date *says* follows the language
    /// the owner picked; which day it names never depends on where the phone is.
    ///
    /// The locale is handed in at every call rather than baked into a stored
    /// style, because a stored one is built once and would keep writing the
    /// language that happened to be current at launch.
    static func format(_ template: Date.FormatStyle, in locale: Locale) -> Date.FormatStyle {
        var style = template
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = locale
        return style
    }

    private static let titleTemplate = Date.FormatStyle().year().month(.wide)

    static func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Exclusive upper bound: the first instant of the following month.
    static func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        return calendar.date(byAdding: .month, value: 1, to: start) ?? start
    }

    /// Every month from the one `start` falls in through the one `end` falls
    /// in, oldest first. Both ends are included, so a strip built from a pair of
    /// dates can show the month either of them sits in.
    static func months(from start: Date, through end: Date) -> [Date] {
        let first = startOfMonth(for: start)
        let last = startOfMonth(for: end)

        guard first <= last else {
            return []
        }

        var months: [Date] = []
        var cursor = first

        while cursor <= last {
            months.append(cursor)

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }

            cursor = next
        }

        return months
    }

    static func title(for date: Date, in locale: Locale) -> String {
        format(titleTemplate, in: locale).format(date)
    }
}
