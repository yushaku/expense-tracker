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

    static func totalMarketValue(
        of holdings: [FundHolding],
        instruments: [FundInstrument],
        kinds: [FundInstrumentKind]
    ) -> Decimal {
        totalMarketValue(
            of: self.holdings(holdings, in: instruments, matching: kinds),
            instruments: instruments
        )
    }

    static func holdings(
        _ holdings: [FundHolding],
        in instruments: [FundInstrument],
        matching kinds: [FundInstrumentKind]
    ) -> [FundHolding] {
        holdings.filter { holding in
            instruments.matching(holding).map { kinds.contains($0.kind) } ?? false
        }
    }

    static func totalUnrealizedProfitLoss(
        of holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> Decimal {
        totalMarketValue(of: holdings, instruments: instruments)
            - totalCostBasis(of: holdings)
    }

    /// Positions whose instrument is missing from the catalogue.
    ///
    /// Joins are resolved in Swift, so a holding can still name an instrument
    /// that has been deleted. Such a position is worth zero, which understates
    /// the portfolio. Valuing it any
    /// other way would be inventing a price, so the number stands and this is
    /// how a caller finds out to say so.
    static func unpriced(
        holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> [FundHolding] {
        holdings.filter { instruments.matching($0) == nil }
    }

    /// What the unpriced positions cost. The one honest figure available for
    /// them: it is the owner's own number and needs no market price.
    static func unpricedCostBasis(
        holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> Decimal {
        totalCostBasis(of: unpriced(holdings: holdings, instruments: instruments))
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
