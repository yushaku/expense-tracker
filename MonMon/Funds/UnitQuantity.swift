import Foundation

/// Parses and formats a fractional unit count for a fund or ETF holding.
/// Accepts both the Vietnamese decimal comma (`1234,56`) and the dot
/// (`1234.56`) so the owner can type whichever the current keyboard offers.
enum UnitQuantity {
    static let maximumFractionDigits = 4

    private static let locale = Locale(identifier: "vi_VN")
    private static let displayFormat = Decimal.FormatStyle(locale: locale)
        .precision(.fractionLength(0...maximumFractionDigits))
        .grouping(.never)
    private static let parseFormat = Decimal.FormatStyle(locale: locale)
        .grouping(.never)

    static func parse(_ text: String) -> Decimal? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return nil
        }

        let normalizedText = trimmedText.replacingOccurrences(of: ".", with: ",")

        // `Decimal(_:format:lenient:)` still accepts trailing junk, so the shape
        // is checked here: an optional sign, digits, and at most one fraction part.
        guard normalizedText.wholeMatch(of: /-?[0-9]+(,[0-9]+)?/) != nil else {
            return nil
        }

        return try? Decimal(normalizedText, format: parseFormat, lenient: false)
    }

    static func format(_ units: Decimal) -> String {
        displayFormat.format(units)
    }
}
