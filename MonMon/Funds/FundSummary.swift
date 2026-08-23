import Foundation

enum FundSummary {
    static func totalCostBasis(of holdings: [FundHolding]) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.costBasis
        }
    }

    static func totalMarketValue(of holdings: [FundHolding]) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.marketValue
        }
    }

    static func totalUnrealizedProfitLoss(of holdings: [FundHolding]) -> Decimal {
        totalMarketValue(of: holdings) - totalCostBasis(of: holdings)
    }
}
