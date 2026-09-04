import Foundation
import Testing

@testable import MonMon

@Suite("CoinGecko quote provider")
struct CoinGeckoQuoteProviderTests {
    private let asOf = Date(timeIntervalSince1970: 1_788_514_800)

    private func provider(_ replies: [String: FixtureTransport.Reply]) -> (
        CoinGeckoQuoteProvider, FixtureTransport
    ) {
        let transport = FixtureTransport(replies)
        return (CoinGeckoQuoteProvider(transport: transport), transport)
    }

    // MARK: - Prices

    @Test("A coin is priced in đồng, stamped with when the price last moved")
    func priceIsReadInDong() async throws {
        let (coinGecko, _) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceBitcoin)
        ])

        let quote = try await coinGecko.latestQuote(
            symbol: "BTC",
            providerID: "bitcoin",
            asOf: asOf
        )

        #expect(quote.symbol == "BTC")
        #expect(quote.pricePerUnit == 2_110_324_943)
        #expect(quote.asOf == Date(timeIntervalSince1970: 1_788_514_270))
        #expect(quote.source == .coinGecko)
    }

    /// The identifier is what CoinGecko keys on, and several coins share a
    /// ticker. Asking by ticker would price whichever one it preferred.
    @Test("The request asks by identifier, not by ticker")
    func requestUsesTheIdentifier() async throws {
        let (coinGecko, transport) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceBitcoin)
        ])

        _ = try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)

        let sent = transport.allSentText()
        #expect(sent.contains("ids=bitcoin"))
        #expect(sent.contains("vs_currencies=vnd"))
    }

    @Test("Without an identifier the ticker is tried, lowercased")
    func missingIdentifierFallsBackToTheTicker() async throws {
        let (coinGecko, transport) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceUnknown)
        ])

        await #expect(throws: FundQuoteError.symbolNotFound) {
            try await coinGecko.latestQuote(symbol: "PEPE", providerID: nil, asOf: asOf)
        }
        #expect(transport.allSentText().contains("ids=pepe"))
    }

    @Test("An identifier CoinGecko does not know reads as a missing symbol")
    func unknownIdentifierIsNotFound() async throws {
        let (coinGecko, _) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceUnknown)
        ])

        await #expect(throws: FundQuoteError.symbolNotFound) {
            try await coinGecko.latestQuote(symbol: "NOPE", providerID: "nope", asOf: asOf)
        }
    }

    /// The whole point of asking for `vnd` is that nothing here converts a
    /// currency. A reply in anything else has no price this app can use.
    @Test("A reply quoted in another currency yields no price")
    func anotherCurrencyIsNotAPrice() async throws {
        let (coinGecko, _) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceWrongCurrency)
        ])

        await #expect(throws: FundQuoteError.noQuoteAvailable) {
            try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)
        }
    }

    @Test("A throttled request keeps its own name rather than reading as offline")
    func throttlingIsReportedAsSuch() async throws {
        let (coinGecko, _) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoThrottled, statusCode: 429)
        ])

        await #expect(throws: FundQuoteError.rateLimited) {
            try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)
        }
    }

    @Test("A body that is not the shape this build knows is a decoding failure")
    func changedShapeIsADecodingFailure() async throws {
        let (coinGecko, _) = provider([
            "simple/price": .init("[1, 2, 3]")
        ])

        await #expect(throws: FundQuoteError.decoding) {
            try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)
        }
    }

    @Test("Offline reports no connection")
    func offlineIsTransport() async throws {
        let coinGecko = CoinGeckoQuoteProvider(transport: FailingTransport())

        await #expect(throws: FundQuoteError.transport) {
            try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)
        }
    }

    // MARK: - Catalogue

    @Test("The catalogue carries identifiers, prices, and logos")
    func catalogueIsRead() async throws {
        let (coinGecko, _) = provider([
            "coins/markets": .init(FundQuoteFixtures.coinGeckoMarkets)
        ])

        let candidates = try await coinGecko.catalogue()

        #expect(candidates.count == 3)
        let bitcoin = try #require(candidates.first)
        #expect(bitcoin.symbol == "BTC")
        #expect(bitcoin.name == "Bitcoin")
        #expect(bitcoin.kind == .crypto)
        #expect(bitcoin.providerID == "bitcoin")
        #expect(bitcoin.pricePerUnit == 2_110_321_939)
        #expect(bitcoin.logoURL?.contains("bitcoin.png") == true)
    }

    @Test("A listing without a price is still offered, unpriced")
    func unpricedListingIsStillOffered() async throws {
        let (coinGecko, _) = provider([
            "coins/markets": .init(FundQuoteFixtures.coinGeckoMarkets)
        ])

        let candidates = try await coinGecko.catalogue()
        let unpriced = try #require(candidates.first { $0.providerID == "unpriced-coin" })

        #expect(unpriced.pricePerUnit == nil)
        #expect(unpriced.priceAsOf == nil)
    }

    @Test("The catalogue is asked for in đồng, by market capitalisation")
    func catalogueRequestIsScoped() async throws {
        let (coinGecko, transport) = provider([
            "coins/markets": .init(FundQuoteFixtures.coinGeckoMarkets)
        ])

        _ = try await coinGecko.catalogue()

        let sent = transport.allSentText()
        #expect(sent.contains("vs_currency=vnd"))
        #expect(sent.contains("order=market_cap_desc"))
        #expect(sent.contains("per_page=\(CoinGeckoQuoteProvider.cataloguePageSize)"))
    }

    // MARK: - Search

    @Test("Search finds coins beyond the catalogue page, without prices")
    func searchReturnsUnpricedCandidates() async throws {
        let (coinGecko, _) = provider([
            "search": .init(FundQuoteFixtures.coinGeckoSearchPepe)
        ])

        let candidates = try await coinGecko.search("pepe")

        #expect(candidates.count == 2)
        let first = try #require(candidates.first)
        #expect(first.symbol == "PEPE")
        #expect(first.providerID == "pepe")
        #expect(first.kind == .crypto)
        #expect(first.pricePerUnit == nil)

        // Two coins whose tickers differ but whose names both match.
        #expect(candidates.map(\.providerID) == ["pepe", "ape-and-pepe"])
    }

    @Test("An empty query asks for nothing")
    func emptyQueryMakesNoRequest() async throws {
        let (coinGecko, transport) = provider([
            "search": .init(FundQuoteFixtures.coinGeckoSearchPepe)
        ])

        #expect(try await coinGecko.search("   ").isEmpty)
        #expect(transport.requestCount == 0)
    }

    @Test("A search that matches nothing is empty rather than an error")
    func emptySearchIsNotAFailure() async throws {
        let (coinGecko, _) = provider([
            "search": .init(FundQuoteFixtures.coinGeckoSearchEmpty)
        ])

        #expect(try await coinGecko.search("nothing at all").isEmpty)
    }

    // MARK: - Privacy

    /// The same boundary the other providers keep: a ticker or an identifier
    /// leaves, and nothing else does.
    @Test("Only identifiers and tickers cross the network boundary")
    func nothingIdentifyingIsSent() async throws {
        let (coinGecko, transport) = provider([
            "simple/price": .init(FundQuoteFixtures.coinGeckoPriceBitcoin),
            "coins/markets": .init(FundQuoteFixtures.coinGeckoMarkets),
            "search": .init(FundQuoteFixtures.coinGeckoSearchPepe),
        ])

        _ = try await coinGecko.latestQuote(symbol: "BTC", providerID: "bitcoin", asOf: asOf)
        _ = try await coinGecko.catalogue()
        _ = try await coinGecko.search("pepe")

        let sent = transport.allSentText()
        #expect(sent.contains("api.coingecko.com"))
        for forbidden in ["units", "balance", "cost", "account", "holding"] {
            #expect(!sent.lowercased().contains(forbidden))
        }
    }
}
