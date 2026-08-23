import Foundation

/// One place to work out a share of a whole, so every chart in the app rounds
/// the same way and guards the same empty case.
enum Percentage {
    /// Share of `total`, in percent, rounded to one decimal place. Zero when
    /// there is nothing to divide by, so an empty chart never divides by zero.
    static func share(of amount: Decimal, in total: Decimal) -> Decimal {
        guard total > 0 else {
            return .zero
        }

        var input = amount / total * 100
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 1, .plain)
        return result
    }

    /// The share written for the screen, e.g. `42,5%`.
    static func label(of amount: Decimal, in total: Decimal) -> String {
        "\(PercentInput.format(share(of: amount, in: total)))%"
    }
}
