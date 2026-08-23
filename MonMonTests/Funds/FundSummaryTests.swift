import Foundation
import Testing

@testable import MonMon

@Suite("Fund summary")
struct FundSummaryTests {
    @Test("No holdings total to zero")
    func emptyHoldingsTotalZero() {
        #expect(FundSummary.totalCostBasis(of: []) == 0)
        #expect(FundSummary.totalMarketValue(of: [], instruments: []) == 0)
        #expect(FundSummary.totalUnrealizedProfitLoss(of: [], instruments: []) == 0)
    }

    @Test("Cost bases and market values add exactly")
    func totalsAddExactly() {
        let fund = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)
        let etf = FundTestFactory.instrument(
            symbol: "FUEVFVND",
            kind: .etf,
            pricePerUnit: 30_000
        )
        let holdings = [
            FundTestFactory.holding(in: fund, units: 1_000, averageCostPerUnit: 20_000),
            FundTestFactory.holding(in: etf, units: 500, averageCostPerUnit: 32_000),
        ]

        #expect(FundSummary.totalCostBasis(of: holdings) == 36_000_000)
        #expect(
            FundSummary.totalMarketValue(of: holdings, instruments: [fund, etf]) == 40_000_000
        )
    }

    @Test("A gain and a loss net against each other")
    func gainAndLossNetOut() {
        let fund = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)
        let etf = FundTestFactory.instrument(
            symbol: "FUEVFVND",
            kind: .etf,
            pricePerUnit: 30_000
        )
        let holdings = [
            FundTestFactory.holding(in: fund, units: 1_000, averageCostPerUnit: 20_000),
            FundTestFactory.holding(in: etf, units: 500, averageCostPerUnit: 32_000),
        ]

        // +5.000.000 ₫ on the fund, −1.000.000 ₫ on the ETF.
        #expect(
            FundSummary.totalUnrealizedProfitLoss(of: holdings, instruments: [fund, etf])
                == 4_000_000
        )
    }

    /// The whole reason the price moved off the position: two lots of one ticker
    /// are valued at one price, and cannot drift apart.
    @Test("Two holdings of one instrument share its price")
    func twoHoldingsShareOnePrice() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 30_000)
        let holdings = [
            FundTestFactory.holding(in: instrument, units: 100, averageCostPerUnit: 20_000),
            FundTestFactory.holding(in: instrument, units: 400, averageCostPerUnit: 25_000),
        ]

        #expect(
            FundSummary.totalMarketValue(of: holdings, instruments: [instrument]) == 15_000_000
        )
        #expect(FundSummary.totalCostBasis(of: holdings) == 12_000_000)
        #expect(FundSummary.totalUnits(for: instrument, holdings: holdings) == 500)
        #expect(FundSummary.holdings(for: instrument, holdings: holdings).count == 2)
    }

    /// Joins are resolved in Swift, so a holding can point at nothing. It must
    /// not crash and must not invent a value.
    @Test("A holding with no instrument is worth nothing")
    func danglingHoldingIsWorthNothing() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 30_000)
        let orphan = FundTestFactory.holding(
            in: FundTestFactory.instrument(symbol: "GONE", pricePerUnit: 10_000),
            units: 100,
            averageCostPerUnit: 20_000
        )

        #expect(FundSummary.totalMarketValue(of: [orphan], instruments: [instrument]) == 0)
        #expect(FundSummary.totalCostBasis(of: [orphan]) == 2_000_000)
    }

    /// Valuing an orphan at zero is the only honest option — any other figure
    /// would be invented — so the guarantee is that a caller can find out.
    @Test("Unpriced positions are reported, not just silently worth nothing")
    func unpricedPositionsAreReported() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 30_000)
        let priced = FundTestFactory.holding(
            in: instrument,
            units: 100,
            averageCostPerUnit: 20_000
        )
        let orphan = FundTestFactory.holding(
            in: FundTestFactory.instrument(symbol: "GONE", pricePerUnit: 10_000),
            units: 50,
            averageCostPerUnit: 30_000
        )
        let holdings = [priced, orphan]
        let catalogue = [instrument]

        let unpriced = FundSummary.unpriced(holdings: holdings, instruments: catalogue)

        #expect(unpriced.count == 1)
        #expect(unpriced.first?.id == orphan.id)
        #expect(
            FundSummary.unpricedCostBasis(holdings: holdings, instruments: catalogue)
                == 1_500_000
        )
        // The total still counts the orphan as nothing; it is now knowable that
        // it did, and by how much cost.
        #expect(FundSummary.totalMarketValue(of: holdings, instruments: catalogue) == 3_000_000)
        #expect(FundSummary.totalCostBasis(of: holdings) == 3_500_000)
    }

    @Test("Nothing is reported when every position is priced")
    func nothingReportedWhenAllPriced() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 30_000)
        let holdings = [
            FundTestFactory.holding(in: instrument, units: 100, averageCostPerUnit: 20_000)
        ]

        #expect(FundSummary.unpriced(holdings: holdings, instruments: [instrument]).isEmpty)
        #expect(FundSummary.unpricedCostBasis(holdings: holdings, instruments: [instrument]) == 0)
    }

    @Test("Cost basis ignores the catalogue entirely")
    func costBasisNeedsNoCatalogue() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 30_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )

        // Refreshing a price must never move the cash side of the app.
        instrument.currentPricePerUnit = 99_000

        #expect(FundSummary.totalCostBasis(of: [holding]) == 20_000_000)
    }
}
