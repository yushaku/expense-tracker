import Foundation

enum FundSummary {
    /// What every position cost. Needs no catalogue: cost basis lives entirely
    /// on the holding, which is why refreshing a price cannot move a cash
    /// balance or the funded amount.
    static func totalCostBasis(of holdings: [FundHolding]) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.costBasis
        }
    }

    /// `instruments` has no default value on purpose — the same reason
    /// `holdings` and `transactions` have none elsewhere. A forgotten argument
    /// would silently value the whole portfolio at zero.
    static func totalMarketValue(
        of holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.marketValue(in: instruments)
        }
    }

    static func totalUnrealizedProfitLoss(
        of holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> Decimal {
        totalMarketValue(of: holdings, instruments: instruments)
            - totalCostBasis(of: holdings)
    }

    /// Every holding of one instrument. Used to block deleting an instrument
    /// that is still held, and to report how many positions would be orphaned.
    static func holdings(
        for instrument: FundInstrument,
        holdings: [FundHolding]
    ) -> [FundHolding] {
        holdings.filter { $0.instrumentID == instrument.id }
    }

    static func totalUnits(
        for instrument: FundInstrument,
        holdings all: [FundHolding]
    ) -> Decimal {
        holdings(for: instrument, holdings: all)
            .reduce(Decimal.zero) { total, holding in
                total + holding.units
            }
    }
}
