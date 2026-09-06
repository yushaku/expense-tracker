import Foundation
import Testing

@testable import MonMon

@Suite("USD exchange rate lookup")
@MainActor
struct USDExchangeRateLoaderTests {
    private let asOf = Date(timeIntervalSince1970: 1_788_538_800)

    private func loader(
        _ body: String = FundQuoteFixtures.coinGeckoTetherRate,
        statusCode: Int = 200
    ) -> (USDExchangeRateLoader, FixtureTransport) {
        let transport = FixtureTransport(["simple/price": .init(body, statusCode: statusCode)])
        return (
            USDExchangeRateLoader(provider: CoinGeckoQuoteProvider(transport: transport)),
            transport
        )
    }

    @Test("The rate arrives in đồng per dollar, stamped with when it moved")
    func rateIsReadInDongPerDollar() async throws {
        let (loader, _) = loader()

        let rate = try #require(await loader.load(asOf: asOf))

        #expect(rate.dongPerDollar == 26_058)
        #expect(rate.asOf == Date(timeIntervalSince1970: 1_788_538_300))
        #expect(loader.phase == .loaded(rate))
    }

    /// The dollar is asked about by the stablecoin coins are bought with, not
    /// by a coin the owner happens to hold.
    @Test("The request asks for the dollar proxy in đồng")
    func requestAsksForTheDollarProxy() async throws {
        let (loader, transport) = loader()

        await loader.load(asOf: asOf)

        let sent = transport.allSentText()
        #expect(sent.contains("ids=\(CoinGeckoQuoteProvider.dollarProxyID)"))
        #expect(sent.contains("vs_currencies=vnd"))
    }

    @Test("A second ask inside the floor reuses what came back")
    func secondAskInsideTheFloorReuses() async throws {
        let (loader, transport) = loader()

        await loader.load(asOf: asOf)
        let afterFirst = transport.requestCount
        let second = await loader.load(asOf: asOf.addingTimeInterval(60))

        #expect(transport.requestCount == afterFirst)
        #expect(second?.dongPerDollar == 26_058)
    }

    @Test("Past the floor it asks again")
    func pastTheFloorItAsksAgain() async throws {
        let (loader, transport) = loader()

        await loader.load(asOf: asOf)
        let afterFirst = transport.requestCount
        await loader.load(
            asOf: asOf.addingTimeInterval(USDExchangeRateLoader.requestFloor + 1)
        )

        #expect(transport.requestCount == afterFirst + 1)
    }

    @Test("Throttling is reported as itself so the owner is told to type a rate")
    func throttlingIsReported() async throws {
        let (loader, _) = loader(FundQuoteFixtures.coinGeckoThrottled, statusCode: 429)

        let rate = await loader.load(asOf: asOf)

        #expect(rate == nil)
        #expect(loader.phase == .failed(.rateLimited))
    }

    @Test("Offline leaves the field to be typed rather than blocking the form")
    func offlineFails() async throws {
        let loader = USDExchangeRateLoader(
            provider: CoinGeckoQuoteProvider(transport: FailingTransport())
        )

        #expect(await loader.load(asOf: asOf) == nil)
        #expect(loader.phase == .failed(.transport))
    }

    @Test("A reply without the dollar in it yields no rate")
    func missingRateYieldsNothing() async throws {
        let (loader, _) = loader(FundQuoteFixtures.coinGeckoPriceUnknown)

        #expect(await loader.load(asOf: asOf) == nil)
        #expect(loader.phase == .failed(.noQuoteAvailable))
    }

    @Test("Every phase but idle says something under the field")
    func phasesCarryCopy() {
        let locale = Locale(identifier: "en")

        #expect(USDExchangeRateLoader.Phase.idle.message(in: locale) == nil)
        #expect(USDExchangeRateLoader.Phase.loading.message(in: locale) != nil)
        #expect(
            USDExchangeRateLoader.Phase
                .loaded(USDExchangeRate(dongPerDollar: 26_058, asOf: asOf))
                .message(in: locale) != nil
        )
        #expect(USDExchangeRateLoader.Phase.failed(.transport).message(in: locale) != nil)
        #expect(USDExchangeRateLoader.Phase.failed(.rateLimited).message(in: locale) != nil)
    }
}
