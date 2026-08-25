import Foundation

enum FundSummary {
    /// What every position cost when it was bought. Needs no catalogue and no
    /// sales: cost basis lives entirely on the holding, which is why refreshing
    /// a price cannot move a cash balance or the funded amount, and why closing
    /// a position cannot either. `CashBalanceSummary.fundedAmount` reads this
    /// figure and needs it whole.
    static func totalCostBasis(of holdings: [FundHolding]) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.costBasis
        }
    }

    /// What the units still held cost. The figure to compare against market
    /// value, because a position that has been half sold is only half open.
    static func totalOpenCostBasis(
        of holdings: [FundHolding],
        sales: [FundSale]
    ) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.remainingCostBasis(sales: sales)
        }
    }

    /// `instruments` has no default value on purpose — the same reason
    /// `holdings` and `transactions` have none elsewhere. A forgotten argument
    /// would silently value the whole portfolio at zero.
    static func totalMarketValue(
        of holdings: [FundHolding],
        instruments: [FundInstrument],
        sales: [FundSale]
    ) -> Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.marketValue(in: instruments, sales: sales)
        }
    }

    static func totalMarketValue(
        of holdings: [FundHolding],
        instruments: [FundInstrument],
        sales: [FundSale],
        kinds: [FundInstrumentKind]
    ) -> Decimal {
        totalMarketValue(
            of: self.holdings(holdings, in: instruments, matching: kinds),
            instruments: instruments,
            sales: sales
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

    /// What the open part of these positions has made on paper. Measured
    /// against the cost of the units still held, so selling at a profit moves
    /// the gain from this figure into the realized one rather than deleting it.
    static func totalUnrealizedProfitLoss(
        of holdings: [FundHolding],
        instruments: [FundInstrument],
        sales: [FundSale]
    ) -> Decimal {
        totalMarketValue(of: holdings, instruments: instruments, sales: sales)
            - totalOpenCostBasis(of: holdings, sales: sales)
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

    /// How much of one instrument is still held. Counts what is left rather
    /// than what was bought, so a fully closed catalogue entry reads as unheld.
    static func totalUnits(
        for instrument: FundInstrument,
        holdings all: [FundHolding],
        sales: [FundSale]
    ) -> Decimal {
        holdings(for: instrument, holdings: all)
            .reduce(Decimal.zero) { total, holding in
                total + holding.remainingUnits(sales: sales)
            }
    }
}
