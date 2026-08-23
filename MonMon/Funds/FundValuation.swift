import Foundation

/// Valuation maths for a fund or ETF holding held at a hand-entered price:
/// `cost basis = units × average cost`, `market value = units × NAV`, both
/// rounded to the đồng. Cost basis is rounded because it is the amount deducted
/// from the funding account, so the cash side stays whole-đồng.
enum FundValuation {
    static func costBasis(units: Decimal, averageCostPerUnit: Decimal) -> Decimal {
        amount(units: units, pricePerUnit: averageCostPerUnit)
    }

    static func marketValue(units: Decimal, currentNAVPerUnit: Decimal) -> Decimal {
        amount(units: units, pricePerUnit: currentNAVPerUnit)
    }

    static func unrealizedProfitLoss(
        units: Decimal,
        averageCostPerUnit: Decimal,
        currentNAVPerUnit: Decimal
    ) -> Decimal {
        marketValue(units: units, currentNAVPerUnit: currentNAVPerUnit)
            - costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
    }

    /// Unrealized return in percent. Zero when there is no cost basis to compare
    /// against, so a holding entered at a zero price never divides by zero.
    static func returnPercent(
        units: Decimal,
        averageCostPerUnit: Decimal,
        currentNAVPerUnit: Decimal
    ) -> Decimal {
        let basis = costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
        guard basis > 0 else {
            return .zero
        }

        let profitLoss = unrealizedProfitLoss(
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit
        )

        return profitLoss / basis * 100
    }

    private static func amount(units: Decimal, pricePerUnit: Decimal) -> Decimal {
        guard units > 0, pricePerUnit > 0 else {
            return .zero
        }

        return rounded(units * pricePerUnit)
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}
