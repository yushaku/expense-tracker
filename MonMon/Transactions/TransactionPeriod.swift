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

    private static let titleFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().year().month(.wide)
        style.calendar = SavingsInterest.calendar
        style.timeZone = SavingsInterest.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()

    static func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Exclusive upper bound: the first instant of the following month.
    static func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        return calendar.date(byAdding: .month, value: 1, to: start) ?? start
    }

    static func title(for date: Date) -> String {
        titleFormat.format(date)
    }
}
