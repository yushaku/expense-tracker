import Foundation
import Testing

@testable import MonMon

@Suite("Fmarket quote provider")
struct FmarketQuoteProviderTests {
    private let asOf = Date(timeIntervalSince1970: 1_787_270_400)

    private func provider(_ replies: [String: FixtureTransport.Reply]) -> (
        FmarketQuoteProvider, FixtureTransport
    ) {
        let transport = FixtureTransport(replies)
        return (FmarketQuoteProvider(transport: transport), transport)
    }

    private var happyPath: [String: FixtureTransport.Reply] {
        [
            "products/filter": .init(FundQuoteFixtures.fmarketFilterVESAF),
            "get-nav-history": .init(FundQuoteFixtures.fmarketNavHistoryVESAF),
        ]
    }

    @Test("The last NAV point becomes the quote, in đồng and dated to its own day")
    func latestNAVBecomesTheQuote() async throws {
        let (fmarket, _) = provider(happyPath)

        let quote = try await fmarket.latestQuote(symbol: "vesaf", asOf: asOf)

        #expect(quote.symbol == "VESAF")
        // Fmarket quotes VND per unit directly. No scaling.
        #expect(quote.pricePerUnit == Decimal(string: "31581.76"))
        #expect(quote.source == .fmarket)
        #expect(quote.asOf == TradingCalendar.calendar.startOfDay(for: asOf))
    }

    @Test("A ticker Fmarket does not list is reported as not found")
    func unknownSymbolIsNotFound() async throws {
        let (fmarket, _) = provider(["products/filter": .init(FundQuoteFixtures.fmarketFilterEmpty)]
        )

        await #expect(throws: FundQuoteError.symbolNotFound) {
            try await fmarket.latestQuote(symbol: "NOPE", asOf: asOf)
        }
    }

    @Test("A listed ticker with no NAV points has no quote available")
    func emptyHistoryHasNoQuote() async throws {
        let (fmarket, _) = provider([
            "products/filter": .init(FundQuoteFixtures.fmarketFilterVESAF),
            "get-nav-history": .init(FundQuoteFixtures.fmarketNavHistoryEmpty),
        ])

        await #expect(throws: FundQuoteError.noQuoteAvailable) {
            try await fmarket.latestQuote(symbol: "VESAF", asOf: asOf)
        }
    }

    @Test("A renamed field is a decoding failure, not a missing quote")
    func renamedFieldFailsDecoding() async throws {
        let (fmarket, _) = provider([
            "products/filter": .init(FundQuoteFixtures.fmarketFilterVESAF),
            "get-nav-history": .init(FundQuoteFixtures.fmarketNavHistoryRenamed),
        ])

        await #expect(throws: FundQuoteError.decoding) {
            try await fmarket.latestQuote(symbol: "VESAF", asOf: asOf)
        }
    }

    @Test("A non-2xx reply is a transport failure")
    func nonSuccessStatusIsTransport() async throws {
        let (fmarket, _) = provider([
            "products/filter": .init(FundQuoteFixtures.fmarketFilterVESAF, statusCode: 400)
        ])

        await #expect(throws: FundQuoteError.transport) {
            try await fmarket.latestQuote(symbol: "VESAF", asOf: asOf)
        }
    }

    @Test("Being offline is a transport failure")
    func offlineIsTransport() async throws {
        let fmarket = FmarketQuoteProvider(transport: FailingTransport())

        await #expect(throws: FundQuoteError.transport) {
            try await fmarket.latestQuote(symbol: "VESAF", asOf: asOf)
        }
    }

    @Test("Search offers the catalogue as open-ended funds")
    func searchOffersFunds() async throws {
        let (fmarket, _) = provider(happyPath)

        let candidates = try await fmarket.search("VESAF")

        #expect(candidates.count == 1)
        #expect(candidates.first?.symbol == "VESAF")
        #expect(candidates.first?.kind == .fund)
        #expect(candidates.first?.name.isEmpty == false)
    }

    /// The privacy contract, checked rather than asserted in a comment.
    @Test("Only the ticker leaves the device")
    func onlyTheTickerIsSent() async throws {
        let (fmarket, transport) = provider(happyPath)
        _ = try await fmarket.latestQuote(symbol: "VESAF", asOf: asOf)

        let sent = transport.allSentText()

        #expect(sent.contains("VESAF"))
        for leak in ["units", "averageCost", "costBasis", "balance", "accountID", "holding"] {
            #expect(!sent.lowercased().contains(leak.lowercased()))
        }
    }
}

@Suite("VNDIRECT quote provider")
struct VNDirectQuoteProviderTests {
    private let asOf = Date(timeIntervalSince1970: 1_787_270_400)

    private func provider(_ replies: [String: FixtureTransport.Reply]) -> (
        VNDirectQuoteProvider, FixtureTransport
    ) {
        let transport = FixtureTransport(replies)
        return (VNDirectQuoteProvider(transport: transport), transport)
    }

    /// The scaling test that matters: `34.2` has to land on exactly 34,200 ₫.
    /// Routing it through a `Double` is how a fund tracker starts reporting
    /// 34199.999999996.
    @Test("A close in thousands scales to exact đồng")
    func closeScalesExactly() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryFUEVFVND)
        ])

        let quote = try await vndirect.latestQuote(symbol: "fuevfvnd", asOf: asOf)

        #expect(quote.symbol == "FUEVFVND")
        #expect(quote.pricePerUnit == Decimal(34_200))
        #expect(quote.source == .vndirect)
    }

    /// `NSNumber.stringValue` formats with `%0.16g` and prints the binary
    /// artefact: this NAV came back as "9348.310000000001". `34.2` does not
    /// expose it, which is how the bug survived the first round of tests.
    @Test("A price whose double exposes its artefact still parses exactly")
    func artefactExposingPriceParsesExactly() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(
                #"{"t":[1787270400],"c":[9.34831],"s":"ok"}"#
            )
        ])

        let quote = try await vndirect.latestQuote(symbol: "AEIF", asOf: asOf)

        #expect(quote.pricePerUnit == Decimal(string: "9348.31"))
        #expect(quote.pricePerUnit != Decimal(9.34831) * 1_000)
    }

    @Test("The bar's own stamp becomes the trading day")
    func stampBecomesTheTradingDay() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryFUEVFVND)
        ])

        let quote = try await vndirect.latestQuote(symbol: "FUEVFVND", asOf: asOf)
        let expected = TradingCalendar.calendar.startOfDay(
            for: Date(timeIntervalSince1970: 1_787_270_400)
        )

        #expect(quote.asOf == expected)
    }

    @Test("A no-data reply has no quote available")
    func noDataHasNoQuote() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryNoData)
        ])

        await #expect(throws: FundQuoteError.noQuoteAvailable) {
            try await vndirect.latestQuote(symbol: "FUEVFVND", asOf: asOf)
        }
    }

    @Test("An ok reply with no bars has no quote available")
    func emptyBarsHaveNoQuote() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryEmpty)
        ])

        await #expect(throws: FundQuoteError.noQuoteAvailable) {
            try await vndirect.latestQuote(symbol: "FUEVFVND", asOf: asOf)
        }
    }

    @Test("A zero close is a malformed reply, not a price")
    func zeroCloseFailsDecoding() async throws {
        let (vndirect, _) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryZeroClose)
        ])

        await #expect(throws: FundQuoteError.decoding) {
            try await vndirect.latestQuote(symbol: "FUEVFVND", asOf: asOf)
        }
    }

    @Test("Search returns the endpoint's display name")
    func searchReturnsDisplayName() async throws {
        let (vndirect, _) = provider([
            "dchart/symbols": .init(FundQuoteFixtures.vndirectSymbolsFUEVFVND)
        ])

        let candidates = try await vndirect.search("FUEVFVND")

        #expect(candidates.count == 1)
        #expect(candidates.first?.symbol == "FUEVFVND")
        #expect(candidates.first?.name == "Quỹ ETF DCVFMVN DIAMOND")
    }

    /// The endpoint answers for open-ended funds too, and describes them wrongly.
    /// A candidate's kind must come from which provider produced it, never from
    /// what the reply claims.
    @Test("A provider's own classification is not trusted")
    func providerClassificationIsNotTrusted() async throws {
        let (vndirect, _) = provider([
            "dchart/symbols": .init(FundQuoteFixtures.vndirectSymbolsVESAF)
        ])

        let candidates = try await vndirect.search("VESAF")

        // The reply says type IFC listed on HOSE. Neither is used.
        #expect(candidates.first?.kind == .etf)
    }

    @Test("Only the ticker leaves the device")
    func onlyTheTickerIsSent() async throws {
        let (vndirect, transport) = provider([
            "dchart/history": .init(FundQuoteFixtures.vndirectHistoryFUEVFVND)
        ])
        _ = try await vndirect.latestQuote(symbol: "FUEVFVND", asOf: asOf)

        let sent = transport.allSentText()

        #expect(sent.contains("FUEVFVND"))
        for leak in ["units", "averageCost", "costBasis", "balance", "accountID", "holding"] {
            #expect(!sent.lowercased().contains(leak.lowercased()))
        }
    }
}

@Suite("Fund quote router")
struct FundQuoteRouterTests {
    private let asOf = Date(timeIntervalSince1970: 1_787_270_400)

    /// Records which provider was asked, so the routing itself can be asserted
    /// without a network shape in the way.
    private struct SpyProvider: FundQuoteProvider {
        let source: FundQuoteSource
        let box: Box

        final class Box: @unchecked Sendable {
            var asked = false
        }

        func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote {
            box.asked = true
            return FundQuote(symbol: symbol, pricePerUnit: 1, asOf: asOf, source: source)
        }

        func search(_ query: String) async throws -> [FundInstrumentCandidate] {
            box.asked = true
            return []
        }
    }

    @Test("A fund routes to Fmarket and an ETF to VNDIRECT")
    func kindDecidesTheProvider() async throws {
        let fmarketBox = SpyProvider.Box()
        let vndirectBox = SpyProvider.Box()
        let router = FundQuoteRouter(
            fmarket: SpyProvider(source: .fmarket, box: fmarketBox),
            vndirect: SpyProvider(source: .vndirect, box: vndirectBox)
        )

        let fundQuote = try await router.latestQuote(symbol: "VESAF", kind: .fund, asOf: asOf)
        #expect(fundQuote.source == .fmarket)
        #expect(fmarketBox.asked)
        #expect(!vndirectBox.asked)

        let etfQuote = try await router.latestQuote(symbol: "FUEVFVND", kind: .etf, asOf: asOf)
        #expect(etfQuote.source == .vndirect)
        #expect(vndirectBox.asked)
    }
}
