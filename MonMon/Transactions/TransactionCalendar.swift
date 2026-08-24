import Foundation

/// One square of the month grid: the day, what it took in and what it paid out,
/// and whether it belongs to the month on show or is spill from the month
/// either side. Spill days are kept rather than blanked so every row is a whole
/// week and the columns stay under their weekday.
struct TransactionCalendarDay: Identifiable, Equatable {
    let date: Date
    let isInMonth: Bool
    let income: Decimal
    let expense: Decimal
    let count: Int

    var id: Date { date }

    var net: Decimal {
        income - expense
    }

    var isEmpty: Bool {
        count == 0
    }
}

/// A row of the grid. Weeks are the unit rather than a flat run of days, so the
/// view never has to work out where a row breaks.
struct TransactionCalendarWeek: Identifiable, Equatable {
    let days: [TransactionCalendarDay]

    var id: Date {
        days.first?.date ?? .distantPast
    }
}

/// Totals a month's transactions day by day, laid out the way a month is read.
///
/// Nothing here draws, and nothing reads the clock: the month is handed in, so
/// the same call gives the same grid in a test as on screen. The calendar is the
/// one `TransactionPeriod` already shares, so the days line up with the ranges
/// the rest of the spending screen filters by.
enum TransactionCalendar {
    private static var calendar: Calendar {
        TransactionPeriod.calendar
    }

    /// The whole weeks covering `month`, oldest first. A month that starts
    /// mid-week keeps the days before it, and one that ends mid-week keeps the
    /// days after it, both marked as outside the month.
    static func weeks(
        of month: Date,
        transactions: [MoneyTransaction]
    ) -> [TransactionCalendarWeek] {
        let monthStart = TransactionPeriod.startOfMonth(for: month)
        let monthEnd = TransactionPeriod.endOfMonth(for: month)
        let totals = totalsByDay(transactions)

        var weeks: [TransactionCalendarWeek] = []
        var rowStart = startOfWeek(for: monthStart)

        while rowStart < monthEnd {
            let days = (0..<7).compactMap { offset -> TransactionCalendarDay? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: rowStart) else {
                    return nil
                }

                let day = calendar.startOfDay(for: date)
                let total = totals[day] ?? DayTotal()

                return TransactionCalendarDay(
                    date: day,
                    isInMonth: day >= monthStart && day < monthEnd,
                    income: total.income,
                    expense: total.expense,
                    count: total.count
                )
            }

            weeks.append(TransactionCalendarWeek(days: days))

            guard let nextRow = calendar.date(byAdding: .weekOfYear, value: 1, to: rowStart) else {
                break
            }

            rowStart = nextRow
        }

        return weeks
    }

    /// What the days of a grid came to, for the line above it. Spill days are
    /// left out: they belong to the months either side, which have their own
    /// grid and their own total.
    static func monthTotals(
        of weeks: [TransactionCalendarWeek]
    ) -> (income: Decimal, expense: Decimal) {
        weeks
            .flatMap(\.days)
            .filter(\.isInMonth)
            .reduce(into: (income: Decimal.zero, expense: Decimal.zero)) { totals, day in
                totals.income += day.income
                totals.expense += day.expense
            }
    }

    private struct DayTotal {
        var income: Decimal = .zero
        var expense: Decimal = .zero
        var count: Int = 0
    }

    private static func totalsByDay(_ transactions: [MoneyTransaction]) -> [Date: DayTotal] {
        transactions.reduce(into: [Date: DayTotal]()) { totals, transaction in
            let day = calendar.startOfDay(for: transaction.occurredAt)
            var total = totals[day] ?? DayTotal()

            switch transaction.kind {
            case .income:
                total.income += transaction.amount
            case .expense:
                total.expense += transaction.amount
            }

            total.count += 1
            totals[day] = total
        }
    }

    /// The first day of the week `date` falls in, by the calendar's own idea of
    /// which day a week starts on.
    private static func startOfWeek(for date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        return calendar.date(byAdding: .day, value: -offset, to: date) ?? date
    }
}
