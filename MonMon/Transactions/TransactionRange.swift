import Foundation

/// How wide a slice of time the spending screen is showing.
enum TransactionRangeScope: String, CaseIterable, Identifiable, Hashable {
    case day
    case month
    case year
    case custom

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .day:
            "Day"
        case .month:
            "Month"
        case .year:
            "Year"
        case .custom:
            "Range"
        }
    }

    /// The unit an arrow steps by. A hand-picked range has no natural step, so
    /// it has none.
    var stepComponent: Calendar.Component? {
        switch self {
        case .day:
            .day
        case .month:
            .month
        case .year:
            .year
        case .custom:
            nil
        }
    }
}

/// A half-open slice of time the spending screen adds up: `start` is included,
/// `end` is not. Every scope reduces to the same pair of dates, so the filtering
/// below it never has to know which one the owner picked.
///
/// Nothing here reads the clock, so tests stay deterministic. The calendar is
/// the one `TransactionPeriod` already shares, so no module depends on the
/// machine's locale or time zone.
struct TransactionRange: Hashable {
    let scope: TransactionRangeScope
    let start: Date
    let end: Date

    private static var calendar: Calendar {
        TransactionPeriod.calendar
    }

    private static let dayTemplate = Date.FormatStyle().day().month(.abbreviated).year()
    private static let yearTemplate = Date.FormatStyle().year()

    private static func day(_ date: Date, in locale: Locale) -> String {
        TransactionPeriod.format(dayTemplate, in: locale).format(date)
    }

    // MARK: - Building

    static func day(containing date: Date) -> Self {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return Self(scope: .day, start: start, end: end)
    }

    static func month(containing date: Date) -> Self {
        Self(
            scope: .month,
            start: TransactionPeriod.startOfMonth(for: date),
            end: TransactionPeriod.endOfMonth(for: date)
        )
    }

    static func year(containing date: Date) -> Self {
        let components = calendar.dateComponents([.year], from: date)
        let start = calendar.date(from: components) ?? date
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        return Self(scope: .year, start: start, end: end)
    }

    /// Both ends are whole days and the pair is ordered, so an owner who picks
    /// the later day first still gets the range they meant.
    static func custom(from first: Date, to second: Date) -> Self {
        let ends = [calendar.startOfDay(for: first), calendar.startOfDay(for: second)].sorted()
        let end = calendar.date(byAdding: .day, value: 1, to: ends[1]) ?? ends[1]
        return Self(scope: .custom, start: ends[0], end: end)
    }

    /// Re-cuts a range to another scope around `anchor`, which is where the
    /// owner was already looking. Switching to a hand-picked range keeps the
    /// two ends currently on show rather than collapsing them to one day.
    func scoped(to scope: TransactionRangeScope, anchoredOn anchor: Date) -> Self {
        switch scope {
        case .day:
            .day(containing: anchor)
        case .month:
            .month(containing: anchor)
        case .year:
            .year(containing: anchor)
        case .custom:
            .custom(from: start, to: lastDay)
        }
    }

    // MARK: - Reading

    /// The last day inside the range, which is what a date field shows for the
    /// upper end. `end` itself is the first instant after the range.
    var lastDay: Date {
        Self.calendar.date(byAdding: .day, value: -1, to: end) ?? start
    }

    var canStep: Bool {
        scope.stepComponent != nil
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Moves the whole range by `steps` of its own unit. A hand-picked range
    /// stays put: its ends were chosen, not derived.
    func stepped(by steps: Int) -> Self {
        guard let component = scope.stepComponent,
            let moved = Self.calendar.date(byAdding: component, value: steps, to: start)
        else {
            return self
        }

        switch scope {
        case .day:
            return .day(containing: moved)
        case .month:
            return .month(containing: moved)
        case .year:
            return .year(containing: moved)
        case .custom:
            return self
        }
    }

    func title(in locale: Locale) -> String {
        switch scope {
        case .day:
            Self.day(start, in: locale)
        case .month:
            TransactionPeriod.title(for: start, in: locale)
        case .year:
            TransactionPeriod.format(Self.yearTemplate, in: locale).format(start)
        case .custom:
            start == lastDay
                ? Self.day(start, in: locale)
                : "\(Self.day(start, in: locale)) – \(Self.day(lastDay, in: locale))"
        }
    }

    /// Reads inside a sentence, where the title alone would be ambiguous about
    /// whether it names a point or a span.
    /// Whole phrases rather than a preposition glued to a title: a language
    /// puts the two together its own way, and some put nothing between them.
    func phrase(in locale: Locale) -> String {
        switch scope {
        case .day:
            AppText.string("on \(title(in: locale))", in: locale)
        case .month, .year:
            AppText.string("in \(title(in: locale))", in: locale)
        case .custom:
            AppText.string(
                "between \(Self.day(start, in: locale)) and \(Self.day(lastDay, in: locale))",
                in: locale
            )
        }
    }

    var stepBackLabel: String {
        switch scope {
        case .day:
            "Previous day"
        case .month:
            "Previous month"
        case .year:
            "Previous year"
        case .custom:
            "Previous range"
        }
    }

    var stepForwardLabel: String {
        switch scope {
        case .day:
            "Next day"
        case .month:
            "Next month"
        case .year:
            "Next year"
        case .custom:
            "Next range"
        }
    }
}
