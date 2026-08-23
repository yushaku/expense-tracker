import Foundation
import Testing

@testable import MonMon

@Suite("Fund valuation")
struct FundValuationTests {
    @Test("Cost basis is units times the average cost")
    func costBasisMultiplies() {
        #expect(
            FundValuation.costBasis(units: 1_000, averageCostPerUnit: 20_000)
                == 20_000_000
        )
    }

    @Test("Market value is units times the current NAV")
    func marketValueMultiplies() {
        #expect(
            FundValuation.marketValue(units: 1_000, currentNAVPerUnit: 25_000)
                == 25_000_000
        )
    }

    @Test("A rising NAV produces a positive profit and return")
    func risingNAVIsAGain() {
        #expect(
            FundValuation.unrealizedProfitLoss(
                units: 1_000,
                averageCostPerUnit: 20_000,
                currentNAVPerUnit: 25_000
            ) == 5_000_000
        )
        #expect(
            FundValuation.returnPercent(
                units: 1_000,
                averageCostPerUnit: 20_000,
                currentNAVPerUnit: 25_000
            ) == 25
        )
    }

    @Test("A falling NAV produces a negative profit and return")
    func fallingNAVIsALoss() {
        #expect(
            FundValuation.unrealizedProfitLoss(
                units: 1_000,
                averageCostPerUnit: 25_000,
                currentNAVPerUnit: 20_000
            ) == -5_000_000
        )
        #expect(
            FundValuation.returnPercent(
                units: 1_000,
                averageCostPerUnit: 25_000,
                currentNAVPerUnit: 20_000
            ) == -20
        )
    }

    @Test("An unchanged NAV leaves no profit and no return")
    func unchangedNAVIsFlat() {
        #expect(
            FundValuation.unrealizedProfitLoss(
                units: 1_000,
                averageCostPerUnit: 20_000,
                currentNAVPerUnit: 20_000
            ) == 0
        )
        #expect(
            FundValuation.returnPercent(
                units: 1_000,
                averageCostPerUnit: 20_000,
                currentNAVPerUnit: 20_000
            ) == 0
        )
    }

    @Test("Fractional units round to the đồng, away from zero on a tie")
    func fractionalUnitsRoundToTheDong() throws {
        let units = try #require(Decimal(string: "1.5"))

        // 1,5 × 3 = 4,5, and .plain rounds a tie away from zero.
        #expect(FundValuation.costBasis(units: units, averageCostPerUnit: 3) == 5)

        let manyUnits = try #require(Decimal(string: "100.5"))
        let price = try #require(Decimal(string: "10.5"))

        // 100,5 × 10,5 = 1055,25.
        #expect(
            FundValuation.costBasis(units: manyUnits, averageCostPerUnit: price) == 1_055
        )
    }

    @Test("Zero or negative units and prices value at zero")
    func nonPositiveInputsValueAtZero() {
        #expect(FundValuation.costBasis(units: 0, averageCostPerUnit: 20_000) == 0)
        #expect(FundValuation.costBasis(units: 1_000, averageCostPerUnit: 0) == 0)
        #expect(FundValuation.marketValue(units: -5, currentNAVPerUnit: 20_000) == 0)
    }

    @Test("A zero cost basis returns zero percent instead of dividing by zero")
    func zeroCostBasisGuardsTheReturn() {
        #expect(
            FundValuation.returnPercent(
                units: 1_000,
                averageCostPerUnit: 0,
                currentNAVPerUnit: 25_000
            ) == 0
        )
    }
}
