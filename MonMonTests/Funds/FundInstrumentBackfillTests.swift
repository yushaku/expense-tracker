import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund instrument backfill")
@MainActor
struct FundInstrumentBackfillTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let day1 = Date(timeIntervalSince1970: 1_700_086_400)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Writes a holding the way a pre-split build did: identity and price on the
    /// position, nothing in `instrumentID`.
    private func insertLegacyHolding(
        into context: ModelContext,
        symbol: String,
        name: String,
        kind: FundHoldingKind = .fund,
        units: Decimal,
        averageCostPerUnit: Decimal,
        navPerUnit: Decimal,
        navAsOf: Date,
        createdAt: Date,
        sourceAccountID: UUID? = nil
    ) -> FundHolding {
        let holding = FundHolding(
            id: UUID(),
            instrumentID: nil,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )
        holding.symbol = symbol
        holding.name = name
        holding.kind = kind
        holding.currentNAVPerUnit = navPerUnit
        holding.navAsOf = navAsOf
        holding.currencyCode = VNDCurrency.code
        context.insert(holding)
        return holding
    }

    @Test("An empty store backfills nothing")
    func emptyStoreBackfillsNothing() throws {
        let container = try makeContainer()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: container.mainContext) == 0)
        #expect(try container.mainContext.fetch(FetchDescriptor<FundInstrument>()).isEmpty)
    }

    @Test("One legacy holding becomes one instrument it points at")
    func oneHoldingBecomesOneInstrument() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let accountID = UUID()
        _ = insertLegacyHolding(
            into: context,
            symbol: "vesaf",
            name: "VinaCapital VESAF",
            units: 1_000,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0,
            sourceAccountID: accountID
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 1)

        let instrument = try #require(
            try context.fetch(FetchDescriptor<FundInstrument>()).first
        )
        let holding = try #require(try context.fetch(FetchDescriptor<FundHolding>()).first)

        #expect(instrument.symbol == "VESAF")
        #expect(instrument.name == "VinaCapital VESAF")
        #expect(instrument.currentPricePerUnit == 25_000)
        #expect(instrument.priceAsOf == day0)
        #expect(instrument.source == .manual)
        #expect(instrument.priceFetchedAt == nil)
        #expect(instrument.autoQuoteEnabled)
        #expect(holding.instrumentID == instrument.id)
        // Everything the position owns is untouched.
        #expect(holding.units == 1_000)
        #expect(holding.averageCostPerUnit == 20_000)
        #expect(holding.sourceAccountID == accountID)
        #expect(holding.costBasis == 20_000_000)
    }

    /// The case the split exists to fix. Two rows for one ticker carried two
    /// prices; they collapse to one instrument at the more recent figure.
    @Test("A duplicated ticker collapses to its most recent price")
    func duplicateTickerCollapsesToNewestPrice() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "vesaf typo",
            kind: .etf,
            units: 400,
            averageCostPerUnit: 22_000,
            navPerUnit: 27_000,
            navAsOf: day1,
            createdAt: day1
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 2)

        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let instrument = try #require(instruments.first)

        #expect(instruments.count == 1)
        // Identity from the oldest row, so the first thing entered wins.
        #expect(instrument.name == "VinaCapital VESAF")
        #expect(instrument.kind == .fund)
        // Price from the newest `navAsOf`, because the older one was already wrong.
        #expect(instrument.currentPricePerUnit == 27_000)
        #expect(instrument.priceAsOf == day1)
        #expect(holdings.allSatisfy { $0.instrumentID == instrument.id })
        #expect(FundSummary.totalMarketValue(of: holdings, instruments: instruments) == 13_500_000)
        #expect(FundSummary.totalCostBasis(of: holdings) == 10_800_000)
    }

    @Test("Two tickers become two instruments")
    func twoTickersBecomeTwoInstruments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        _ = insertLegacyHolding(
            into: context,
            symbol: "FUEVFVND",
            name: "Diamond ETF",
            kind: .etf,
            units: 200,
            averageCostPerUnit: 32_000,
            navPerUnit: 30_000,
            navAsOf: day0,
            createdAt: day1
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 2)

        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())

        #expect(instruments.count == 2)
        #expect(Set(instruments.map(\.symbol)) == ["VESAF", "FUEVFVND"])
        #expect(instruments.first { $0.symbol == "FUEVFVND" }?.kind == .etf)
    }

    /// It runs on every launch, so running twice must be indistinguishable from
    /// running once.
    @Test("Running twice changes nothing the second time")
    func backfillIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 1)
        let firstID = try #require(
            try context.fetch(FetchDescriptor<FundInstrument>()).first
        ).id

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 0)

        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        #expect(instruments.count == 1)
        #expect(instruments.first?.id == firstID)
    }

    /// A holding written after the split already points somewhere and must not
    /// be re-pointed at a instrument minted from its blank legacy fields.
    @Test("A holding that already points at an instrument is left alone")
    func linkedHoldingIsLeftAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 100,
            averageCostPerUnit: 20_000
        )
        context.insert(instrument)
        context.insert(holding)
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 0)

        #expect(try context.fetch(FetchDescriptor<FundInstrument>()).count == 1)
        #expect(holding.instrumentID == instrument.id)
    }

    @Test("A legacy holding joins an instrument the catalogue already has")
    func legacyHoldingJoinsExistingInstrument() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 31_000)
        context.insert(instrument)
        _ = insertLegacyHolding(
            into: context,
            symbol: "vesaf",
            name: "VinaCapital VESAF",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 1)

        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let holdings = try context.fetch(FetchDescriptor<FundHolding>())

        #expect(instruments.count == 1)
        // The catalogue's price wins; the legacy figure is not written over it.
        #expect(instruments.first?.currentPricePerUnit == 31_000)
        #expect(holdings.first?.instrumentID == instrument.id)
    }

    /// A second copy of the ticker and price on the position is the shape that
    /// let two rows disagree in the first place. Once the values are on an
    /// instrument, the position must not keep them.
    @Test("Linking empties the pre-split fields it copied")
    func linkingEmptiesThePreSplitFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            kind: .etf,
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 1)

        let holding = try #require(try context.fetch(FetchDescriptor<FundHolding>()).first)
        let instrument = try #require(
            try context.fetch(FetchDescriptor<FundInstrument>()).first
        )

        #expect(holding.symbol.isEmpty)
        #expect(holding.name.isEmpty)
        #expect(holding.currencyCode.isEmpty)
        #expect(holding.currentNAVPerUnit == 0)
        #expect(holding.navAsOf == Date(timeIntervalSince1970: 0))
        // The values are not lost, they moved.
        #expect(instrument.symbol == "VESAF")
        #expect(instrument.name == "VinaCapital VESAF")
        #expect(instrument.kind == .etf)
        #expect(instrument.currentPricePerUnit == 25_000)
        #expect(instrument.priceAsOf == day0)
        // The position keeps everything that is actually its own.
        #expect(holding.units == 100)
        #expect(holding.averageCostPerUnit == 20_000)
        #expect(holding.costBasis == 2_000_000)
    }

    @Test("Completion is reported once every position is linked")
    func completionIsReportedWhenNothingIsWaiting() throws {
        let container = try makeContainer()
        let context = container.mainContext
        #expect(try FundInstrumentBackfill.isComplete(in: context))

        _ = insertLegacyHolding(
            into: context,
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        try context.save()

        #expect(try !FundInstrumentBackfill.isComplete(in: context))

        _ = try FundInstrumentBackfill.runIfNeeded(in: context)

        #expect(try FundInstrumentBackfill.isComplete(in: context))
    }

    @Test("A holding with no ticker is skipped rather than given a blank instrument")
    func holdingWithoutSymbolIsSkipped() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = insertLegacyHolding(
            into: context,
            symbol: "   ",
            name: "",
            units: 100,
            averageCostPerUnit: 20_000,
            navPerUnit: 25_000,
            navAsOf: day0,
            createdAt: day0
        )
        try context.save()

        #expect(try FundInstrumentBackfill.runIfNeeded(in: context) == 0)
        #expect(try context.fetch(FetchDescriptor<FundInstrument>()).isEmpty)
    }
}

@Suite("Fund instrument seed")
struct FundInstrumentSeedTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let day1 = Date(timeIntervalSince1970: 1_700_086_400)

    private func snapshot(
        symbol: String,
        name: String = "Name",
        kind: FundHoldingKind = .fund,
        nav: Decimal,
        navAsOf: Date,
        createdAt: Date
    ) -> FundHoldingSnapshot {
        FundHoldingSnapshot(
            holdingID: UUID(),
            name: name,
            symbol: symbol,
            kind: kind,
            currentNAVPerUnit: nav,
            navAsOf: navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("Grouping is case-insensitive and keeps first-seen order")
    func groupingIsCaseInsensitiveAndOrdered() {
        let groups = FundInstrumentSeed.group([
            snapshot(symbol: "vesaf", nav: 25_000, navAsOf: day0, createdAt: day0),
            snapshot(symbol: "FUEVFVND", nav: 30_000, navAsOf: day0, createdAt: day0),
            snapshot(symbol: " VESAF ", nav: 27_000, navAsOf: day1, createdAt: day1),
        ])

        #expect(groups.map(\.symbol) == ["VESAF", "FUEVFVND"])
        #expect(groups[0].holdingIDs.count == 2)
        #expect(groups[0].pricePerUnit == 27_000)
    }

    @Test("An empty input produces no groups")
    func emptyInputProducesNoGroups() {
        #expect(FundInstrumentSeed.group([]).isEmpty)
    }

    @Test("A blank name falls back to the ticker")
    func blankNameFallsBackToTicker() {
        let groups = FundInstrumentSeed.group([
            snapshot(symbol: "VESAF", name: "", nav: 25_000, navAsOf: day0, createdAt: day0)
        ])

        #expect(groups.first?.name == "VESAF")
    }
}
