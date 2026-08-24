import Foundation

/// One price, and the trading day it belongs to.
struct FundQuote: Sendable, Equatable {
    /// Uppercased, as stored on the instrument.
    let symbol: String
    /// VND per unit, already normalised. Providers quote in different units;
    /// nothing outside a provider ever sees the raw figure.
    let pricePerUnit: Decimal
    /// The other side of a two-sided quote. Present for gold, where
    /// `pricePerUnit` is the shop's buy and this is the shop's sell.
    let askPricePerUnit: Decimal?
    /// Start of the trading day the price belongs to, not when it was fetched.
    let asOf: Date
    let source: FundQuoteSource

    init(
        symbol: String,
        pricePerUnit: Decimal,
        askPricePerUnit: Decimal? = nil,
        asOf: Date,
        source: FundQuoteSource
    ) {
        self.symbol = symbol
        self.pricePerUnit = pricePerUnit
        self.askPricePerUnit = askPricePerUnit
        self.asOf = asOf
        self.source = source
    }
}

/// A catalogue entry a provider can offer, before the owner confirms it.
struct FundInstrumentCandidate: Sendable, Equatable, Identifiable {
    let symbol: String
    let name: String
    /// Whichever provider produced the candidate decides this. A provider's own
    /// `type` field is not trusted: VNDIRECT returns VESAF as an ETF listed on
    /// HOSE, and it is neither.
    let kind: FundInstrumentKind
    /// The price the listing already carried, when it carried one. Fmarket's
    /// catalogue call returns every fund's NAV alongside its name, so importing
    /// the whole list costs one request rather than one per fund.
    let pricePerUnit: Decimal?
    /// The shop's sell price when the candidate carries a gold spread.
    let askPricePerUnit: Decimal?
    /// The trading day that price belongs to.
    let priceAsOf: Date?
    /// The fund management company, as the listing gives it. Empty when the
    /// listing does not say.
    let owner: String

    var id: String { symbol }

    init(
        symbol: String,
        name: String,
        kind: FundInstrumentKind,
        pricePerUnit: Decimal? = nil,
        askPricePerUnit: Decimal? = nil,
        priceAsOf: Date? = nil,
        owner: String = ""
    ) {
        self.symbol = symbol
        self.name = name
        self.kind = kind
        self.pricePerUnit = pricePerUnit
        self.askPricePerUnit = askPricePerUnit
        self.priceAsOf = priceAsOf
        self.owner = owner
    }
}

extension FundInstrumentCandidate {
    /// The manager's name with the legal boilerplate taken off.
    ///
    /// Fmarket gives it in full — "CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ VINACAPITAL" —
    /// and 26 of those stacked as section headings is a wall of the same eight
    /// words. What distinguishes them is the tail, so that is what shows.
    var displayOwner: String {
        let trimmed = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Other"
        }

        let upper = trimmed.uppercased()
        for prefix in Self.ownerPrefixes where upper.hasPrefix(prefix) {
            let tail = upper.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return tail.isEmpty ? trimmed : tail
        }

        return trimmed
    }

    /// Longest first, so the more specific phrasing wins over the shorter one it
    /// starts with.
    private static let ownerPrefixes = [
        "CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ ĐẦU TƯ CHỨNG KHOÁN",
        "CÔNG TY TNHH QUẢN LÝ QUỸ ĐẦU TƯ CHỨNG KHOÁN",
        "CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ ĐẦU TƯ",
        "CÔNG TY TNHH QUẢN LÝ QUỸ ĐẦU TƯ",
        "CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ",
        "CÔNG TY TNHH QUẢN LÝ QUỸ",
        "CÔNG TY QUẢN LÝ QUỸ",
    ]
}

enum FundQuoteError: Error, Equatable {
    /// The provider has no such symbol.
    case symbolNotFound
    /// The symbol exists but carries no usable data point.
    case noQuoteAvailable
    /// Offline, timed out, or a non-2xx reply.
    case transport
    /// The response arrived but is not the shape this build knows.
    case decoding
    /// Refused locally, before any request went out.
    case rateLimited
}

protocol FundQuoteProvider: Sendable {
    var source: FundQuoteSource { get }
    func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote
    func search(_ query: String) async throws -> [FundInstrumentCandidate]
}

/// Picks the provider for an instrument.
///
/// The choice comes from `FundInstrumentKind`, which the owner sets, and never from
/// anything a provider says about the instrument. Both endpoints will happily
/// answer for a symbol they describe incorrectly.
struct FundQuoteRouter: Sendable {
    private let fmarket: any FundQuoteProvider
    private let vndirect: any FundQuoteProvider
    private let vangToday: any FundQuoteProvider

    init(
        fmarket: any FundQuoteProvider = FmarketQuoteProvider(),
        vndirect: any FundQuoteProvider = VNDirectQuoteProvider(),
        vangToday: any FundQuoteProvider = VangTodayQuoteProvider()
    ) {
        self.fmarket = fmarket
        self.vndirect = vndirect
        self.vangToday = vangToday
    }

    func provider(for kind: FundInstrumentKind) -> any FundQuoteProvider {
        switch kind {
        case .fund:
            fmarket
        case .etf:
            vndirect
        case .gold:
            vangToday
        }
    }

    func latestQuote(
        symbol: String,
        kind: FundInstrumentKind,
        asOf: Date
    ) async throws -> FundQuote {
        try await provider(for: kind).latestQuote(symbol: symbol, asOf: asOf)
    }

    func search(
        _ query: String,
        kind: FundInstrumentKind
    ) async throws -> [FundInstrumentCandidate] {
        try await provider(for: kind).search(query)
    }
}
