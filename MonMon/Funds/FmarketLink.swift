import Foundation

/// Where an instrument can be read about on the web.
///
/// Fmarket lists open-ended funds only, and its fund pages are addressed by
/// ticker: `fmarket.vn/quy/vesaf`. An ETF is traded on the exchange rather than
/// sold through Fmarket, so it has no page there and gets no link rather than
/// one that lands on a not-found screen.
enum FmarketLink {
    static func url(for instrument: FundInstrument) -> URL? {
        guard instrument.kind == .fund else {
            return nil
        }

        return url(forSymbol: instrument.symbol)
    }

    static func url(forSymbol symbol: String) -> URL? {
        let slug =
            symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // The ticker becomes part of a path, so anything that is not a plain
        // ticker is refused rather than escaped: a stored symbol is owner-typed,
        // and a link is not the place to find out it holds a slash.
        guard !slug.isEmpty, slug.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return nil
        }

        return URL(string: "https://fmarket.vn/quy/\(slug)")
    }
}
