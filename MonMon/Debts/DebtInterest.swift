import Foundation

/// Simple interest on a debt: `interest = principal × rate / 100 × days / 365`,
/// rounded to the đồng.
///
/// It delegates to `SavingsInterest` rather than repeating the formula, so the
/// two sides of the ledger can never round a đồng differently and there is one
/// Gregorian calendar pinned to `Asia/Ho_Chi_Minh`, not two.
///
/// Nothing here reads the clock. Anything that needs today takes it as `asOf`,
/// so every figure is reproducible.
enum DebtInterest {
    static var calendar: Calendar { SavingsInterest.calendar }

    static func dayCount(from startDate: Date, to endDate: Date) -> Int {
        SavingsInterest.dayCount(from: startDate, to: endDate)
    }

    /// Interest over a span. A backwards span projects nothing rather than a
    /// credit, because `SavingsInterest` refuses a non-positive day count.
    static func projected(
        principal: Decimal,
        annualRatePercent: Decimal,
        from startDate: Date,
        to endDate: Date
    ) -> Decimal {
        SavingsInterest.projectedInterest(
            principal: principal,
            annualRatePercent: annualRatePercent,
            days: dayCount(from: startDate, to: endDate)
        )
    }

    /// Whether the agreed date has passed. Whether the debt is *overdue* also
    /// depends on something still being owed, which only `DebtSummary` can say.
    static func isPastDue(dueDate: Date?, asOf: Date) -> Bool {
        guard let dueDate else { return false }
        return dayCount(from: asOf, to: dueDate) < 0
    }

    /// Whole days until the agreed date, negative once it has passed, and `nil`
    /// for an open-ended debt.
    static func daysUntilDue(dueDate: Date?, asOf: Date) -> Int? {
        guard let dueDate else { return nil }
        return dayCount(from: asOf, to: dueDate)
    }
}
