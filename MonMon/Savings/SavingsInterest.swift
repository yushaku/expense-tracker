import Foundation

/// Simple-interest maths for a Vietnamese term deposit paid at maturity:
/// `interest = principal × rate / 100 × days / 365`, rounded to the đồng.
enum SavingsInterest {
    static let daysPerYear = 365

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .gmt
        return calendar
    }()

    static func maturityDate(openedAt: Date, termMonths: Int) -> Date {
        calendar.date(byAdding: .month, value: termMonths, to: openedAt) ?? openedAt
    }

    static func dayCount(from startDate: Date, to endDate: Date) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func projectedInterest(
        principal: Decimal,
        annualRatePercent: Decimal,
        days: Int
    ) -> Decimal {
        guard principal > 0, annualRatePercent > 0, days > 0 else {
            return .zero
        }

        let exact =
            principal * annualRatePercent / 100 * Decimal(days) / Decimal(daysPerYear)
        return rounded(exact)
    }

    static func maturityValue(
        principal: Decimal,
        annualRatePercent: Decimal,
        days: Int
    ) -> Decimal {
        principal
            + projectedInterest(
                principal: principal,
                annualRatePercent: annualRatePercent,
                days: days
            )
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}
