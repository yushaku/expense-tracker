import Foundation

/// Parses and formats an annual interest rate expressed in percent.
/// Accepts both the Vietnamese decimal comma (`5,6`) and the dot (`5.6`)
/// so the owner can type whichever the current keyboard offers.
enum PercentInput {
    private static let locale = Locale(identifier: "vi_VN")
    private static let displayFormat = Decimal.FormatStyle(locale: locale)
        .precision(.fractionLength(0...2))
        .grouping(.never)
    private static let parseFormat = Decimal.FormatStyle(locale: locale)
        .grouping(.never)

    static func parse(_ text: String) -> Decimal? {
        var trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedText.hasSuffix("%") {
            trimmedText.removeLast()
            trimmedText = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

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

    static func format(_ rate: Decimal) -> String {
        displayFormat.format(rate)
    }

    static func formatWithSymbol(_ rate: Decimal) -> String {
        "\(format(rate))%/năm"
    }
}
