import Foundation

enum VNDCurrency {
    static let code = "VND"

    /// Display tiers, largest first. Amounts below a thousand keep their đồng
    /// suffix; anything larger is abbreviated so long balances stay readable in
    /// cards, rows, and chart axes.
    private static let tiers: [(threshold: Decimal, divisor: Decimal, suffix: String)] = [
        (1_000_000_000, 1_000_000_000, "B"),
        (1_000_000, 1_000_000, "M"),
        (1_000, 1_000, "k"),
        (0, 1, "đ"),
    ]

    private static let locale = Locale(identifier: "vi_VN")
    private static let numberFormat = Decimal.FormatStyle(locale: locale)
        .grouping(.automatic)
    private static let compactFormat =
        numberFormat
        .precision(.fractionLength(0...1))
    private static let wholeFormat =
        numberFormat
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

    /// An abbreviated amount: `100đ`, `1k`, `1,5k`, `1,2M`, `1B`.
    static func format(_ amount: Decimal) -> String {
        let isNegative = amount < 0
        let magnitude = isNegative ? -amount : amount

        var tierIndex = tiers.firstIndex { magnitude >= $0.threshold } ?? tiers.count - 1
        var scaled = scale(magnitude, at: tierIndex)

        // Rounding can push a value onto the next tier: 999.960 reads as 1M, not
        // 1000k, and 999,6 reads as 1k, not 1000đ.
        if scaled >= 1000, tierIndex > 0 {
            tierIndex -= 1
            scaled = scale(magnitude, at: tierIndex)
        }

        let digits =
            isWholeTier(tierIndex)
            ? wholeFormat.format(scaled) : compactFormat.format(scaled)
        return (isNegative ? "-" : "") + digits + tiers[tierIndex].suffix
    }

    static func format(_ amount: Double) -> String {
        format(Decimal(amount))
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

    /// The đồng tier shows whole numbers; the abbreviated tiers keep one decimal.
    private static func isWholeTier(_ index: Int) -> Bool {
        index == tiers.count - 1
    }

    private static func scale(_ magnitude: Decimal, at index: Int) -> Decimal {
        var input = magnitude / tiers[index].divisor
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, isWholeTier(index) ? 0 : 1, .plain)
        return rounded
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
