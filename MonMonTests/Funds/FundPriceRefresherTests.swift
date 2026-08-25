import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund price refresher")
@MainActor
struct FundPriceRefresherTests {
    /// A Monday at 16:00 in the shared calendar, so the last completed trading
    /// day is that Monday and anything older is stale.
    private var asOf: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 24
        components.hour = 16
        return TradingCalendar.calendar.date(from: components) ?? .distantPast
    }

    private func day(_ offset: Int) -> Date {
        TradingCalendar.calendar.date(byAdding: .day, value: offset, to: startOfAsOf) ?? asOf
    }

    private var startOfAsOf: Date {
        TradingCalendar.calendar.startOfDay(for: asOf)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Answers with a fixed quote, or throws, and counts how often it was asked.
    private struct StubProvider: FundQuoteProvider {
        let source: FundQuoteSource
        var price: Decimal = 30_000
        var askPrice: Decimal?
        var asOf: Date = .distantPast
        var error: FundQuoteError?
        let calls: Calls

        final class Calls: @unchecked Sendable {
            private(set) var count = 0
            private(set) var symbols: [String] = []

            func record(_ symbol: String) {
                count += 1
                symbols.append(symbol)
            }
        }

        func latestQuote(symbol: String, asOf requested: Date) async throws -> FundQuote {
            calls.record(symbol)
            if let error {
                throw error
            }
            return FundQuote(
                symbol: symbol,
                pricePerUnit: price,
                askPricePerUnit: askPrice,
                asOf: self.asOf,
                source: source
            )
        }

        func search(_ query: String) async throws -> [FundInstrumentCandidate] {
            []
        }
    }

    private func refresher(
        price: Decimal = 30_000,
        askPrice: Decimal? = nil,
        quoteDay: Date? = nil,
        error: FundQuoteError? = nil
    ) -> (FundPriceRefresher, StubProvider.Calls) {
        let calls = StubProvider.Calls()
        let stub = StubProvider(
            source: .fmarket,
            price: price,
            askPrice: askPrice,
            asOf: quoteDay ?? startOfAsOf,
            error: error,
            calls: calls
        )
        return (
            FundPriceRefresher(
                router: FundQuoteRouter(
                    fmarket: stub,
                    vndirect: stub,
                    vangToday: stub
                )
            ),
            calls
        )
    }

    @Test("A refresh stores both sides of a gold quote")
    func goldRefreshStoresBidAndAsk() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(
            symbol: "SJL1L10",
            kind: .gold,
            pricePerUnit: 145_000_000,
            priceAsOf: day(-1)
        )
        context.insert(instrument)
        context.insert(
            FundTestFactory.holding(
                in: instrument,
                units: 1,
                averageCostPerUnit: 140_000_000
            )
        )
        try context.save()

        let (refresher, calls) = refresher(
            price: 147_000_000,
            askPrice: 150_000_000
        )
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments,
            holdings: holdings,
            sales: [],
            in: context,
            asOf: asOf
        )

        #expect(calls.count == 1)
        #expect(instrument.currentPricePerUnit == 147_000_000)
        #expect(instrument.askPricePerUnit == 150_000_000)
    }

    @Test("A quote without an ask clears a previously stored ask")
    func quoteWithoutAskClearsAsk() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10))
        instrument.askPricePerUnit = 26_000
        try context.save()

        let (refresher, _) = refresher(price: 31_581)
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments,
            holdings: holdings,
            sales: [],
            in: context,
            asOf: asOf
        )

        #expect(instrument.askPricePerUnit == .zero)
    }

    private func seed(
        _ context: ModelContext,
        priceAsOf: Date,
        autoQuoteEnabled: Bool = true,
        held: Bool = true,
        symbol: String = "VESAF"
    ) -> FundInstrument {
        let instrument = FundTestFactory.instrument(
            symbol: symbol,
            pricePerUnit: 25_000,
            priceAsOf: priceAsOf,
            autoQuoteEnabled: autoQuoteEnabled
        )
        context.insert(instrument)

        if held {
            context.insert(
                FundTestFactory.holding(in: instrument, units: 100, averageCostPerUnit: 20_000)
            )
        }

        return instrument
    }

    private func fetch(_ context: ModelContext) throws -> ([FundInstrument], [FundHolding]) {
        (
            try context.fetch(FetchDescriptor<FundInstrument>()),
            try context.fetch(FetchDescriptor<FundHolding>())
        )
    }

    @Test("A stale price is replaced with the quote, and its source recorded")
    func staleInstrumentIsUpdated() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10))
        try context.save()

        let (refresher, calls) = refresher(price: 31_581)
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 1)
        #expect(instrument.currentPricePerUnit == 31_581)
        #expect(instrument.priceAsOf == startOfAsOf)
        #expect(instrument.source == .fmarket)
        #expect(instrument.priceFetchedAt == asOf)
        #expect(refresher.outcomes[instrument.id]?.isUpdate == true)
    }

    /// Cost basis lives on the position, so a new price must not be able to move
    /// a single đồng of cash.
    @Test("Refreshing moves market value and leaves every cash figure alone")
    func refreshLeavesTheCashSideAlone() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 100_000_000,
            currencyCode: VNDCurrency.code,
            createdAt: startOfAsOf
        )
        context.insert(account)
        let instrument = FundTestFactory.instrument(
            pricePerUnit: 25_000,
            priceAsOf: day(-10)
        )
        context.insert(instrument)
        context.insert(
            FundTestFactory.holding(
                in: instrument,
                units: 100,
                averageCostPerUnit: 20_000,
                sourceAccountID: account.id
            )
        )
        try context.save()

        let (before, holdingsBefore) = try fetch(context)
        let availableBefore = CashBalanceSummary.available(
            for: account,
            deposits: [],
            holdings: holdingsBefore,
            withdrawals: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )
        #expect(
            FundSummary.totalMarketValue(of: holdingsBefore, instruments: before, sales: [])
                == 2_500_000)

        let (refresher, _) = refresher(price: 40_000)
        await refresher.refresh(
            instruments: before, holdings: holdingsBefore, sales: [], in: context,
            asOf: asOf)

        let (after, holdingsAfter) = try fetch(context)

        #expect(
            FundSummary.totalMarketValue(of: holdingsAfter, instruments: after, sales: [])
                == 4_000_000)
        #expect(FundSummary.totalCostBasis(of: holdingsAfter) == 2_000_000)
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: holdingsAfter,
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == availableBefore
        )
    }

    /// A stale figure the owner can see beats a hole where a price used to be.
    @Test("A failure writes nothing and says why")
    func failureKeepsTheKnownGoodPrice() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10))
        instrument.askPricePerUnit = 26_000
        try context.save()

        let (refresher, _) = refresher(error: .transport)
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(instrument.currentPricePerUnit == 25_000)
        #expect(instrument.askPricePerUnit == 26_000)
        #expect(instrument.priceAsOf == day(-10))
        #expect(instrument.source == .manual)
        #expect(instrument.priceFetchedAt == nil)
        #expect(refresher.outcomes[instrument.id] == .failed(.transport))
        #expect(
            refresher.outcomes[instrument.id]?.message(in: Locale(identifier: "en"))
                == "No connection")
    }

    @Test("One ticker failing leaves the others updated")
    func oneFailureDoesNotStopTheRest() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let good = seed(context, priceAsOf: day(-10), symbol: "VESAF")
        let bad = seed(context, priceAsOf: day(-10), symbol: "MISSING")
        try context.save()

        let calls = StubProvider.Calls()
        // Fails only for the second ticker, so the first has to have been asked
        // and written before the failure lands.
        struct SelectiveProvider: FundQuoteProvider {
            let source = FundQuoteSource.fmarket
            let quoteDay: Date
            let calls: StubProvider.Calls

            func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote {
                calls.record(symbol)
                if symbol == "MISSING" {
                    throw FundQuoteError.symbolNotFound
                }
                return FundQuote(
                    symbol: symbol, pricePerUnit: 31_581, asOf: quoteDay, source: source)
            }

            func search(_ query: String) async throws -> [FundInstrumentCandidate] { [] }
        }

        let provider = SelectiveProvider(quoteDay: startOfAsOf, calls: calls)
        let refresher = FundPriceRefresher(
            router: FundQuoteRouter(fmarket: provider, vndirect: provider))
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 2)
        #expect(good.currentPricePerUnit == 31_581)
        #expect(bad.currentPricePerUnit == 25_000)
        #expect(refresher.outcomes[bad.id] == .failed(.symbolNotFound))
        #expect(
            refresher.outcomes[bad.id]?.message(in: Locale(identifier: "en")) == "Symbol not found"
        )
    }

    /// Ten positions in one ticker are one question, not ten.
    @Test("Many holdings of one instrument cost one request")
    func manyHoldingsCostOneRequest() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000, priceAsOf: day(-10))
        context.insert(instrument)
        for _ in 0..<10 {
            context.insert(
                FundTestFactory.holding(in: instrument, units: 10, averageCostPerUnit: 20_000)
            )
        }
        try context.save()

        let (refresher, calls) = refresher()
        let (instruments, holdings) = try fetch(context)
        #expect(holdings.count == 10)

        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 1)
    }

    @Test("An instrument nobody holds makes no request")
    func unheldInstrumentIsSkipped() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10), held: false)
        try context.save()

        let (refresher, calls) = refresher()
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 0)
        #expect(refresher.outcomes[instrument.id] == .unchanged(.notHeld))
    }

    @Test("Automatic quotes switched off makes no request")
    func autoQuoteOffIsSkipped() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10), autoQuoteEnabled: false)
        try context.save()

        let (refresher, calls) = refresher()
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 0)
        #expect(refresher.outcomes[instrument.id] == .unchanged(.automaticQuotesOff))
    }

    @Test("A price already on the newest possible day makes no request")
    func currentPriceIsSkipped() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        // A fund is current at T+1, so yesterday's NAV is as fresh as it gets.
        let instrument = seed(context, priceAsOf: day(-1))
        try context.save()

        let (refresher, calls) = refresher()
        let (instruments, holdings) = try fetch(context)
        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)

        #expect(calls.count == 0)
        #expect(refresher.outcomes[instrument.id] == .unchanged(.alreadyCurrent))
    }

    @Test("A second refresh inside fifteen minutes makes no request")
    func requestFloorHolds() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = seed(context, priceAsOf: day(-10))
        try context.save()

        // The quote itself is old — a fund whose manager has not published for a
        // week and a half — so writing it leaves the instrument still stale.
        // The floor is then the only thing that can stop the second call.
        let (refresher, calls) = refresher(quoteDay: day(-10))
        let (instruments, holdings) = try fetch(context)

        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)
        #expect(calls.count == 1)

        await refresher.refresh(
            instruments: instruments,
            holdings: holdings,
            sales: [],
            in: context,
            asOf: asOf.addingTimeInterval(60)
        )

        #expect(calls.count == 1)
        #expect(refresher.outcomes[instrument.id] == .unchanged(.askedTooRecently))
    }

    @Test("Past the floor, it asks again")
    func floorExpires() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = seed(context, priceAsOf: day(-10))
        try context.save()

        let (refresher, calls) = refresher(quoteDay: day(-10))
        let (instruments, holdings) = try fetch(context)

        await refresher.refresh(
            instruments: instruments, holdings: holdings, sales: [], in: context,
            asOf: asOf)
        await refresher.refresh(
            instruments: instruments,
            holdings: holdings,
            sales: [],
            in: context,
            asOf: asOf.addingTimeInterval(FundPriceRefresher.requestFloor + 1)
        )

        #expect(calls.count == 2)
    }

    @Test("Refresh is offered only when something could actually be fetched")
    func refreshIsOfferedOnlyWhenUseful() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (refresher, _) = refresher()

        #expect(!refresher.hasAnythingToRefresh(instruments: [], holdings: [], sales: []))

        _ = seed(context, priceAsOf: day(-10), held: false)
        try context.save()
        var (instruments, holdings) = try fetch(context)
        #expect(
            !refresher.hasAnythingToRefresh(instruments: instruments, holdings: holdings, sales: [])
        )

        _ = seed(context, priceAsOf: day(-10), symbol: "FUEVFVND")
        try context.save()
        (instruments, holdings) = try fetch(context)
        #expect(
            refresher.hasAnythingToRefresh(instruments: instruments, holdings: holdings, sales: []))
    }
}
