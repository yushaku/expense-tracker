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
        guard !trimmedText.isEmpty, let normalizedText = normalizedInput(trimmedText) else {
            return nil
        }

        return try? Decimal(normalizedText, format: numberFormat, lenient: false)
    }

    /// Groups the integer digits while preserving the fractional digits the
    /// owner is still typing. Invalid text is left untouched so validation can
    /// report it instead of silently deleting input.
    static func formatInput(_ text: String) -> String {
        normalizedInput(text) ?? text
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

    private static func normalizedInput(_ text: String) -> String? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count <= 2 else {
            return nil
        }

        var integerDigits = String(parts[0])
        var sign = ""
        if let first = integerDigits.first, first == "-" || first == "+" {
            sign = String(first)
            integerDigits.removeFirst()
        }

        integerDigits.removeAll { $0 == "." }
        guard !integerDigits.isEmpty, integerDigits.allSatisfy(\.isNumber) else {
            return nil
        }

        var reversedGroupedDigits: [Character] = []
        for (index, digit) in integerDigits.reversed().enumerated() {
            if index > 0, index.isMultiple(of: 3) {
                reversedGroupedDigits.append(".")
            }
            reversedGroupedDigits.append(digit)
        }

        let groupedInteger = sign + String(reversedGroupedDigits.reversed())
        guard parts.count == 2 else {
            return groupedInteger
        }

        let fractionDigits = String(parts[1])
        guard fractionDigits.allSatisfy(\.isNumber) else {
            return nil
        }
        return groupedInteger + "," + fractionDigits
    }
}
