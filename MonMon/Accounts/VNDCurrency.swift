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
}
