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

    /// How a date is written when a screen has no format of its own: short
    /// enough for a card, and always carrying the year, since a debt or a
    /// deposit can be older than the year on show.
    static let dayTemplate = Date.FormatStyle().day().month(.abbreviated).year()

    static func day(_ date: Date, in locale: Locale) -> String {
        format(dayTemplate, in: locale).format(date)
    }

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
        steps(of: .month, from: startOfMonth(for: start), through: startOfMonth(for: end))
    }

    static func startOfYear(for date: Date) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Every year from the one `start` falls in through the one `end` falls in,
    /// oldest first, on the same both-ends-included footing as `months`.
    static func years(from start: Date, through end: Date) -> [Date] {
        steps(of: .year, from: startOfYear(for: start), through: startOfYear(for: end))
    }

    /// Every day from `start` through `end`, oldest first, both included.
    static func days(from start: Date, through end: Date) -> [Date] {
        steps(
            of: .day,
            from: calendar.startOfDay(for: start),
            through: calendar.startOfDay(for: end)
        )
    }

    /// Walks one unit at a time from the first boundary to the last. Callers
    /// hand in dates already cut to the unit, so the walk never drifts.
    private static func steps(
        of component: Calendar.Component,
        from first: Date,
        through last: Date
    ) -> [Date] {
        guard first <= last else {
            return []
        }

        var dates: [Date] = []
        var cursor = first

        while cursor <= last {
            dates.append(cursor)

            guard let next = calendar.date(byAdding: component, value: 1, to: cursor) else {
                break
            }

            cursor = next
        }

        return dates
    }

    static func title(for date: Date, in locale: Locale) -> String {
        format(titleTemplate, in: locale).format(date)
    }
}
