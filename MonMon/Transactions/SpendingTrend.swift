import Foundation

/// How wide one point on the trend is: one step finer than the period being
/// looked at, so a month is read as its days and a year as its months.
enum SpendingTrendUnit {
    case day
    case month

    /// The widest hand-picked range still drawn a day at a time. Past it, a line
    /// of daily points is noise on a phone-width card, and the question the card
    /// answers — how the spending sat over the period — survives being asked one
    /// month at a time.
    static let dayLimit = 92

    var component: Calendar.Component {
        switch self {
        case .day:
            .day
        case .month:
            .month
        }
    }

    func start(of date: Date) -> Date {
        switch self {
        case .day:
            TransactionPeriod.calendar.startOfDay(for: date)
        case .month:
            TransactionPeriod.startOfMonth(for: date)
        }
    }

    func starts(from first: Date, through last: Date) -> [Date] {
        switch self {
        case .day:
            TransactionPeriod.days(from: first, through: last)
        case .month:
            TransactionPeriod.months(from: first, through: last)
        }
    }
}

/// One bucket of the trend: what went out and what came in over it. Both figures
/// are positive, as amounts are stored; which direction they name is the field
/// they sit in.
struct SpendingTrendPoint: Identifiable, Equatable {
    let start: Date
    let expense: Decimal
    let income: Decimal

    var id: Date { start }
}

/// Money out and money in, bucket by bucket, over the period on show.
///
/// The totals above the card say what a period came to; this says how it got
/// there — whether a month went in one afternoon or a little at a time, and
/// where the income landed against it.
///
/// Nothing here reads the clock: `today` is handed in, so tests stay
/// deterministic, and the calendar is the one `TransactionPeriod` shares.
enum SpendingTrend {
    /// The unit a range is drawn in, or `nil` when it has nothing finer worth a
    /// line. A single day is one point, and one point is not a trend.
    static func unit(for range: TransactionRange) -> SpendingTrendUnit? {
        switch range.scope {
        case .day:
            nil
        case .month:
            .day
        case .year:
            .month
        case .custom:
            spannedDays(of: range) <= SpendingTrendUnit.dayLimit ? .day : .month
        }
    }

    /// - Parameter transactions: already narrowed to the period on show, the
    ///   same set every other card on the screen reads. Keeping the filtering
    ///   outside means a card filtered to one direction correctly draws the
    ///   other flat rather than quietly reaching past the filter for it.
    static func points(
        of transactions: [MoneyTransaction],
        in range: TransactionRange,
        today: Date = .now
    ) -> [SpendingTrendPoint] {
        guard let unit = unit(for: range) else {
            return []
        }

        // A period still running is only drawn as far as it has got. Filling
        // the rest of it in at zero would draw the months that have not
        // happened yet as a collapse in spending.
        let last = range.contains(today) ? today : range.lastDay
        let starts = unit.starts(from: range.start, through: last)

        guard let first = starts.first, let final = starts.last else {
            return []
        }

        let totals = totals(of: transactions, unit: unit, from: first, through: final)

        // Buckets that recorded nothing stay in at zero: a quiet week is a flat
        // line, not a gap the line jumps over.
        return starts.map { start in
            let total = totals[start] ?? Total()

            return SpendingTrendPoint(
                start: start,
                expense: total.expense,
                income: total.income
            )
        }
    }

    private struct Total {
        var expense: Decimal = .zero
        var income: Decimal = .zero
    }

    private static func totals(
        of transactions: [MoneyTransaction],
        unit: SpendingTrendUnit,
        from first: Date,
        through final: Date
    ) -> [Date: Total] {
        let calendar = TransactionPeriod.calendar
        let end = calendar.date(byAdding: unit.component, value: 1, to: final) ?? final
        var totals: [Date: Total] = [:]

        for transaction in transactions
        where transaction.occurredAt >= first && transaction.occurredAt < end {
            let start = unit.start(of: transaction.occurredAt)
            var total = totals[start] ?? Total()

            switch transaction.kind {
            case .expense:
                total.expense += transaction.amount
            case .income:
                total.income += transaction.amount
            }

            totals[start] = total
        }

        return totals
    }

    /// How many whole days a range covers, both ends included.
    private static func spannedDays(of range: TransactionRange) -> Int {
        TransactionPeriod.calendar
            .dateComponents([.day], from: range.start, to: range.end)
            .day ?? 0
    }
}
