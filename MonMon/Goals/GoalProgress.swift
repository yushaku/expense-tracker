import Foundation

struct GoalProgressSnapshot: Equatable {
    let remainingAmount: Decimal
    let requiredMonthlyContribution: Decimal
    let forecastCompletionDate: Date?
    let progress: Double
    let isComplete: Bool
}

enum GoalProgress {
    static func snapshot(
        goal: FinancialGoal,
        asOf: Date,
        calendar: Calendar = .current
    ) -> GoalProgressSnapshot {
        let remaining = max(0, goal.targetAmount - goal.earmarkedAmount)
        let isComplete = remaining == 0
        let required =
            isComplete
            ? Decimal.zero
            : divideRoundingUp(
                remaining,
                by: monthsThrough(goal.targetDate, from: asOf, calendar: calendar)
            )

        let progress: Double
        if goal.targetAmount > 0 {
            progress = min(
                max(
                    NSDecimalNumber(decimal: goal.earmarkedAmount / goal.targetAmount)
                        .doubleValue,
                    0
                ),
                1
            )
        } else {
            progress = 0
        }

        return GoalProgressSnapshot(
            remainingAmount: remaining,
            requiredMonthlyContribution: required,
            forecastCompletionDate: forecastDate(
                remaining: remaining,
                monthlyContribution: goal.monthlyContribution,
                asOf: asOf,
                calendar: calendar
            ),
            progress: progress,
            isComplete: isComplete
        )
    }

    private static func monthsThrough(
        _ targetDate: Date,
        from asOf: Date,
        calendar: Calendar
    ) -> Int {
        let start = startOfMonth(asOf, calendar: calendar)
        let target = startOfMonth(targetDate, calendar: calendar)
        let distance = calendar.dateComponents([.month], from: start, to: target).month ?? 0
        return max(1, distance + 1)
    }

    private static func forecastDate(
        remaining: Decimal,
        monthlyContribution: Decimal,
        asOf: Date,
        calendar: Calendar
    ) -> Date? {
        guard remaining > 0 else {
            return asOf
        }
        guard monthlyContribution > 0 else {
            return nil
        }

        let months = decimalCeiling(remaining / monthlyContribution)
        let start = startOfMonth(asOf, calendar: calendar)
        guard let monthAfterCompletion = calendar.date(byAdding: .month, value: months, to: start)
        else {
            return nil
        }
        return calendar.date(byAdding: .day, value: -1, to: monthAfterCompletion)
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func divideRoundingUp(_ amount: Decimal, by divisor: Int) -> Decimal {
        var input = amount / Decimal(divisor)
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 0, .up)
        return result
    }

    private static func decimalCeiling(_ value: Decimal) -> Int {
        var input = value
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 0, .up)
        return max(1, NSDecimalNumber(decimal: result).intValue)
    }
}
