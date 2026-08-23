import Foundation

/// One price, and the trading day it belongs to.
struct FundQuote: Sendable, Equatable {
    /// Uppercased, as stored on the instrument.
    let symbol: String
    /// VND per unit, already normalised. Providers quote in different units;
    /// nothing outside a provider ever sees the raw figure.
    let pricePerUnit: Decimal
    /// Start of the trading day the price belongs to, not when it was fetched.
    let asOf: Date
    let source: FundQuoteSource
}

/// A catalogue entry a provider can offer, before the owner confirms it.
struct FundInstrumentCandidate: Sendable, Equatable {
    let symbol: String
    let name: String
    /// Whichever provider produced the candidate decides this. A provider's own
    /// `type` field is not trusted: VNDIRECT returns VESAF as an ETF listed on
    /// HOSE, and it is neither.
    let kind: FundHoldingKind
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
/// The choice comes from `FundHoldingKind`, which the owner sets, and never from
/// anything a provider says about the instrument. Both endpoints will happily
/// answer for a symbol they describe incorrectly.
struct FundQuoteRouter: Sendable {
    private let fmarket: any FundQuoteProvider
    private let vndirect: any FundQuoteProvider

    init(
        fmarket: any FundQuoteProvider = FmarketQuoteProvider(),
        vndirect: any FundQuoteProvider = VNDirectQuoteProvider()
    ) {
        self.fmarket = fmarket
        self.vndirect = vndirect
    }

    func provider(for kind: FundHoldingKind) -> any FundQuoteProvider {
        switch kind {
        case .fund:
            fmarket
        case .etf:
            vndirect
        }
    }

    func latestQuote(symbol: String, kind: FundHoldingKind, asOf: Date) async throws -> FundQuote {
        try await provider(for: kind).latestQuote(symbol: symbol, asOf: asOf)
    }

    func search(_ query: String, kind: FundHoldingKind) async throws -> [FundInstrumentCandidate] {
        try await provider(for: kind).search(query)
    }
}
