import Foundation
import Testing

@testable import MonMon

@Suite("Fund summary")
struct FundSummaryTests {
    private let navAsOf = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeHolding(
        units: Decimal,
        averageCostPerUnit: Decimal,
        currentNAVPerUnit: Decimal
    ) -> FundHolding {
        FundHolding(
            id: UUID(),
            name: "Holding",
            symbol: "VESAF",
            kind: .fund,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit,
            navAsOf: navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: navAsOf
        )
    }

    @Test("No holdings total to zero")
    func emptyHoldingsTotalZero() {
        #expect(FundSummary.totalCostBasis(of: []) == 0)
        #expect(FundSummary.totalMarketValue(of: []) == 0)
        #expect(FundSummary.totalUnrealizedProfitLoss(of: []) == 0)
    }

    @Test("Cost bases and market values add exactly")
    func totalsAddExactly() {
        let holdings = [
            makeHolding(units: 1_000, averageCostPerUnit: 20_000, currentNAVPerUnit: 25_000),
            makeHolding(units: 500, averageCostPerUnit: 32_000, currentNAVPerUnit: 30_000),
        ]

        #expect(FundSummary.totalCostBasis(of: holdings) == 36_000_000)
        #expect(FundSummary.totalMarketValue(of: holdings) == 40_000_000)
    }

    @Test("A gain and a loss net against each other")
    func gainAndLossNetOut() {
        let holdings = [
            makeHolding(units: 1_000, averageCostPerUnit: 20_000, currentNAVPerUnit: 25_000),
            makeHolding(units: 500, averageCostPerUnit: 32_000, currentNAVPerUnit: 30_000),
        ]

        // +5.000.000 ₫ on the fund, −1.000.000 ₫ on the ETF.
        #expect(FundSummary.totalUnrealizedProfitLoss(of: holdings) == 4_000_000)
    }
}
