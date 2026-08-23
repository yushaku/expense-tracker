import Foundation

enum VNDCurrency {
    static let code = "VND"

    private static let locale = Locale(identifier: "vi_VN")
    private static let numberFormat = Decimal.FormatStyle(locale: locale)
        .grouping(.automatic)
    private static let currencyFormat = Decimal.FormatStyle.Currency(
        code: code,
        locale: locale
    )
    .precision(.fractionLength(0))
    private static let unitPriceFormat = Decimal.FormatStyle.Currency(
        code: code,
        locale: locale
    )
    .precision(.fractionLength(0...2))

    static func parse(_ text: String) -> Decimal? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        return try? Decimal(trimmedText, format: numberFormat, lenient: false)
    }

    static func format(_ amount: Decimal) -> String {
        currencyFormat.format(amount)
    }

    /// Grouped digits without the currency symbol, for prefilling an editable
    /// amount field with a value the same parser accepts back.
    static func formatPlain(_ amount: Decimal) -> String {
        numberFormat.format(amount)
    }

    /// A price for a single unit, which unlike a balance can carry fractions of
    /// a đồng, so it keeps up to two decimals instead of rounding to a whole one.
    static func formatUnitPrice(_ amount: Decimal) -> String {
        unitPriceFormat.format(amount)
    }
}
