import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund holding persistence")
@MainActor
struct FundHoldingPersistenceTests {
    private let referenceDate = FundTestFactory.referenceDate

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("A holding round-trips its position fields")
    func holdingRoundTripsPositionFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let units = try #require(Decimal(string: "1234.5678"))
        let instrument = FundTestFactory.instrument(
            symbol: "FUEVFVND",
            kind: .etf,
            pricePerUnit: 29_850
        )
        let sourceAccountID = UUID()
        let holding = FundTestFactory.holding(
            in: instrument,
            units: units,
            averageCostPerUnit: 24_500,
            sourceAccountID: sourceAccountID
        )
        context.insert(instrument)
        context.insert(holding)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<FundHolding>()).first)
        let savedInstrument = try #require(
            try context.fetch(FetchDescriptor<FundInstrument>()).first
        )

        #expect(saved.instrumentID == savedInstrument.id)
        #expect(saved.units == units)
        #expect(saved.averageCostPerUnit == 24_500)
        #expect(saved.sourceAccountID == sourceAccountID)
        #expect(saved.createdAt == referenceDate)
    }

    @Test("An instrument round-trips its identity and its price")
    func instrumentRoundTripsFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fetchedAt = Date(timeIntervalSince1970: 1_700_086_400)
        let instrument = FundTestFactory.instrument(
            symbol: "VESAF",
            name: "VinaCapital VESAF",
            kind: .fund,
            pricePerUnit: try #require(Decimal(string: "31581.76")),
            source: .fmarket,
            priceFetchedAt: fetchedAt,
            autoQuoteEnabled: false
        )
        context.insert(instrument)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<FundInstrument>()).first)

        #expect(saved.symbol == "VESAF")
        #expect(saved.name == "VinaCapital VESAF")
        #expect(saved.kind == .fund)
        #expect(saved.currentPricePerUnit == Decimal(string: "31581.76"))
        #expect(saved.priceAsOf == referenceDate)
        #expect(saved.source == .fmarket)
        #expect(saved.priceFetchedAt == fetchedAt)
        #expect(saved.autoQuoteEnabled == false)
        #expect(saved.currencyCode == "VND")
    }

    /// The whole point of the split: two positions in one ticker cannot disagree
    /// about what it is worth, because there is only one price to disagree with.
    @Test("Two holdings of one instrument move together when its price changes")
    func twoHoldingsFollowOnePrice() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let first = FundTestFactory.holding(
            in: instrument,
            units: 100,
            averageCostPerUnit: 20_000
        )
        let second = FundTestFactory.holding(
            in: instrument,
            units: 300,
            averageCostPerUnit: 22_000
        )
        context.insert(instrument)
        context.insert(first)
        context.insert(second)
        try context.save()

        var instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        var holdings = try context.fetch(FetchDescriptor<FundHolding>())
        #expect(FundSummary.totalMarketValue(of: holdings, instruments: instruments) == 10_000_000)

        try #require(instruments.first).currentPricePerUnit = 30_000
        try context.save()

        instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        holdings = try context.fetch(FetchDescriptor<FundHolding>())

        #expect(FundSummary.totalMarketValue(of: holdings, instruments: instruments) == 12_000_000)
        // Cost basis is a position's own figure and never follows the market.
        #expect(FundSummary.totalCostBasis(of: holdings) == 8_600_000)
    }

    @Test("A holding with no funding source stores no account id")
    func unlinkedHoldingStoresNoAccountID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        context.insert(instrument)
        context.insert(
            FundTestFactory.holding(in: instrument, units: 1_000, averageCostPerUnit: 20_000)
        )
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<FundHolding>()).first)

        #expect(saved.sourceAccountID == nil)
    }

    @Test("Deleting a holding restores the account's available balance")
    func deletingHoldingRestoresAvailableBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 148_900_000,
            currencyCode: VNDCurrency.code,
            createdAt: referenceDate
        )
        context.insert(account)
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: account.id
        )
        context.insert(instrument)
        context.insert(holding)
        try context.save()

        var holdings = try context.fetch(FetchDescriptor<FundHolding>())
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: holdings,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
            )
                == 128_900_000
        )

        context.delete(holding)
        try context.save()

        holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())

        #expect(accounts.count == 1)
        #expect(holdings.isEmpty)
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: holdings,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
            )
                == 148_900_000
        )
    }

    /// Deleting an instrument out from under a position leaves the position
    /// pointing at nothing. The store permits it — there is no referential
    /// integrity here — so the editor's guard is what actually prevents it, and
    /// the value has to degrade rather than crash.
    @Test("A holding whose instrument is gone values at zero without crashing")
    func orphanedHoldingValuesAtZero() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )
        context.insert(instrument)
        context.insert(holding)
        try context.save()

        context.delete(instrument)
        try context.save()

        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let holdings = try context.fetch(FetchDescriptor<FundHolding>())

        #expect(instruments.isEmpty)
        #expect(holdings.count == 1)
        #expect(FundSummary.totalMarketValue(of: holdings, instruments: instruments) == 0)
        #expect(FundSummary.totalCostBasis(of: holdings) == 20_000_000)
    }

    @Test("Editing a holding through the draft rewrites its stored values")
    func editingThroughDraftRewritesValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceAccountID = UUID()
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: sourceAccountID
        )
        context.insert(instrument)
        context.insert(holding)
        try context.save()

        var draft = FundDraft(holding: holding)
        draft.unitsText = "500"

        // Editing adds this holding's own cost basis back to the spendable balance.
        try draft.apply(to: holding, availableSourceBalance: holding.costBasis)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<FundHolding>()).first)
        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())

        #expect(saved.units == 500)
        #expect(saved.averageCostPerUnit == 20_000)
        #expect(saved.instrumentID == instrument.id)
        #expect(saved.marketValue(in: instruments) == 12_500_000)
        #expect(saved.sourceAccountID == sourceAccountID)
    }
}
