import Foundation
import Testing

@testable import MonMon

@Suite("vang.today quote provider")
struct VangTodayQuoteProviderTests {
    private let asOf = Date(timeIntervalSince1970: 1_787_270_400)

    private func provider(_ reply: FixtureTransport.Reply) -> (
        VangTodayQuoteProvider, FixtureTransport
    ) {
        let transport = FixtureTransport(["api/prices": reply])
        return (VangTodayQuoteProvider(transport: transport), transport)
    }

    @Test("Buy and sell prices are exact đồng per lượng")
    func bidAndAskBecomeTheQuote() async throws {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodaySJC9999))

        let quote = try await provider.latestQuote(symbol: " sjl1l10 ", asOf: asOf)

        #expect(quote.symbol == "SJL1L10")
        #expect(quote.pricePerUnit == 147_000_000)
        #expect(quote.askPricePerUnit == 150_000_000)
        #expect(quote.source == .vangToday)
    }

    @Test("The date owns asOf and the intraday timestamp is ignored")
    func dateOwnsAsOf() async throws {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodaySJC9999))

        let quote = try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 24
        let expected = TradingCalendar.calendar.date(from: components) ?? .distantPast

        #expect(quote.asOf == expected)
        #expect(quote.asOf != Date(timeIntervalSince1970: 1_787_544_005))
    }

    @Test("Only the type code leaves the device")
    func onlyTheTypeCodeLeaves() async throws {
        let (provider, transport) = provider(.init(FundQuoteFixtures.vangTodaySJC9999))
        _ = try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)

        let sent = transport.allSentText()
        #expect(sent.contains("type=SJL1L10"))
        for leak in ["units", "averageCost", "costBasis", "balance", "accountID", "holding"] {
            #expect(!sent.lowercased().contains(leak.lowercased()))
        }
    }

    @Test("A reply carrying another type is not the requested symbol")
    func unknownCodeIsNotFound() async {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodayUnknownType))

        await #expect(throws: FundQuoteError.symbolNotFound) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("An explicit provider failure is symbol not found")
    func failureIsNotFound() async {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodayFailure))

        await #expect(throws: FundQuoteError.symbolNotFound) {
            try await provider.latestQuote(symbol: "NOPE", asOf: asOf)
        }
    }

    @Test("A numeric success flag is a decoding failure")
    func numericSuccessFailsDecoding() async {
        let payload = """
            {"success":1,"date":"2026-08-24","type":"SJL1L10",
             "name":"SJC 9999","buy":147000000,"sell":150000000}
            """
        let (provider, _) = provider(.init(payload))

        await #expect(throws: FundQuoteError.decoding) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("A renamed price field is a decoding failure")
    func renamedFieldFailsDecoding() async {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodayRenamedBuy))

        await #expect(throws: FundQuoteError.decoding) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("A zero buy price is a decoding failure")
    func zeroBuyFailsDecoding() async {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodayZeroBuy))

        await #expect(throws: FundQuoteError.decoding) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("A non-2xx reply is a transport failure")
    func nonSuccessStatusIsTransport() async {
        let (provider, _) = provider(
            .init(FundQuoteFixtures.vangTodaySJC9999, statusCode: 503)
        )

        await #expect(throws: FundQuoteError.transport) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("Being offline is a transport failure")
    func offlineIsTransport() async {
        let provider = VangTodayQuoteProvider(transport: FailingTransport())

        await #expect(throws: FundQuoteError.transport) {
            try await provider.latestQuote(symbol: "SJL1L10", asOf: asOf)
        }
    }

    @Test("The catalogue contains only VND gold and carries both prices")
    func catalogueExcludesWorldGold() async throws {
        let (provider, _) = provider(.init(FundQuoteFixtures.vangTodayCatalogue))

        let candidates = try await provider.catalogue()

        #expect(candidates.map(\.symbol).sorted() == ["DOHCML", "SJL1L10"])
        #expect(candidates.allSatisfy { $0.kind == .gold })
        let sjc = candidates.first { $0.symbol == "SJL1L10" }
        #expect(sjc?.pricePerUnit == 147_000_000)
        #expect(sjc?.askPricePerUnit == 150_000_000)
        #expect(sjc?.owner == "SJC")
    }

    @Test("Search filters the one-request catalogue locally")
    func searchFiltersLocally() async throws {
        let (provider, transport) = provider(.init(FundQuoteFixtures.vangTodayCatalogue))

        let candidates = try await provider.search("doji")

        #expect(candidates.map(\.symbol) == ["DOHCML"])
        #expect(transport.requestCount == 1)
    }
}
