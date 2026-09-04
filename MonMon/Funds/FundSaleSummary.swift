import Foundation

/// What sales do to the positions they came out of and to the accounts they paid
/// into.
///
/// The counterpart of `DebtSummary`, and it reads the same way: nothing here
/// takes a default value, because a forgotten argument would silently report a
/// position as still fully held and a balance as smaller than it is.
enum FundSaleSummary {
    static func sales(for holding: FundHolding, sales: [FundSale]) -> [FundSale] {
        sales
            .filter { $0.holdingID == holding.id }
            .sorted { $0.soldAt > $1.soldAt }
    }

    static func unitsSold(for holding: FundHolding, sales: [FundSale]) -> Decimal {
        sales.reduce(Decimal.zero) { total, sale in
            sale.holdingID == holding.id ? total + sale.units : total
        }
    }

    /// What is still held out of one lot.
    ///
    /// Deliberately not clamped at zero, for the reason `DebtSummary.outstanding`
    /// is not: clamping would let a sale bank its proceeds while the units it
    /// sold stayed in the portfolio, and net worth would climb with no screen
    /// explaining why. `FundSaleDraft` refuses to oversell, so a negative figure
    /// can only come from a store edited by hand, and it should be visible when
    /// it does.
    static func remainingUnits(of holding: FundHolding, sales: [FundSale]) -> Decimal {
        holding.units - unitsSold(for: holding, sales: sales)
    }

    static func isClosed(_ holding: FundHolding, sales: [FundSale]) -> Bool {
        remainingUnits(of: holding, sales: sales) <= 0
    }

    /// Every sale out of one lot, oldest first — the order a position is closed
    /// in, rather than the order it is read in.
    static func hasSales(_ holding: FundHolding, sales: [FundSale]) -> Bool {
        sales.contains { $0.holdingID == holding.id }
    }

    static func totalProceeds(of sales: [FundSale]) -> Decimal {
        sales.reduce(Decimal.zero) { total, sale in
            total + sale.proceeds
        }
    }

    static func totalFees(of sales: [FundSale]) -> Decimal {
        sales.reduce(Decimal.zero) { $0 + $1.fee }
    }

    /// Splits one transaction fee across several lot-level sale records. The
    /// final positive-weight lot receives the rounding remainder so the stored
    /// fees always add back to the single amount the owner entered.
    static func allocateFee(_ fee: Decimal, weights: [Decimal]) -> [Decimal] {
        let totalWeight = weights.reduce(Decimal.zero) { total, weight in
            total + max(weight, .zero)
        }
        guard fee > 0, totalWeight > 0,
            let finalIndex = weights.lastIndex(where: { $0 > 0 })
        else {
            return weights.map { _ in .zero }
        }

        var allocated = Decimal.zero
        return weights.enumerated().map { index, weight in
            guard weight > 0 else {
                return .zero
            }

            let portion: Decimal
            if index == finalIndex {
                portion = fee - allocated
            } else {
                var raw = fee * weight / totalWeight
                var rounded = Decimal.zero
                NSDecimalRound(&rounded, &raw, 0, .plain)
                portion = rounded
            }

            allocated += portion
            return portion
        }
    }

    static func realizedProfitLoss(for holding: FundHolding, sales: [FundSale]) -> Decimal {
        sales.reduce(Decimal.zero) { total, sale in
            guard sale.holdingID == holding.id else {
                return total
            }

            return total + sale.realizedProfitLoss(costPerUnit: holding.averageCostPerUnit)
        }
    }

    /// What the units sold out of this lot originally cost. What a realized
    /// return is measured against.
    static func costBasisSold(for holding: FundHolding, sales: [FundSale]) -> Decimal {
        FundValuation.costBasis(
            units: unitsSold(for: holding, sales: sales),
            averageCostPerUnit: holding.averageCostPerUnit
        )
    }

    /// The realized return in percent. Zero when nothing was sold, so a lot
    /// nobody has touched never divides by zero — the same guard
    /// `FundValuation.returnPercent` makes.
    static func realizedReturnPercent(for holding: FundHolding, sales: [FundSale]) -> Decimal {
        let basis = costBasisSold(for: holding, sales: sales)
        guard basis > 0 else {
            return .zero
        }

        return realizedProfitLoss(for: holding, sales: sales) / basis * 100
    }

    static func totalCostBasisSold(of sales: [FundSale], holdings: [FundHolding]) -> Decimal {
        var costs: [UUID: Decimal] = [:]
        for holding in holdings {
            costs[holding.id] = holding.averageCostPerUnit
        }

        return sales.reduce(Decimal.zero) { total, sale in
            guard let holdingID = sale.holdingID, let costPerUnit = costs[holdingID] else {
                return total
            }

            return total + sale.costBasis(costPerUnit: costPerUnit)
        }
    }

    static func totalRealizedReturnPercent(
        of sales: [FundSale],
        holdings: [FundHolding]
    ) -> Decimal {
        let basis = totalCostBasisSold(of: sales, holdings: holdings)
        guard basis > 0 else {
            return .zero
        }

        return totalRealizedProfitLoss(of: sales, holdings: holdings) / basis * 100
    }

    /// What every sale out of these lots made.
    ///
    /// A sale naming a lot that is not in `holdings` contributes nothing rather
    /// than being valued at a zero cost, which would report the whole proceeds
    /// as profit. That is the same refusal `FundSummary.unpriced` makes for a
    /// position whose instrument has gone.
    static func totalRealizedProfitLoss(
        of sales: [FundSale],
        holdings: [FundHolding]
    ) -> Decimal {
        var costs: [UUID: Decimal] = [:]
        for holding in holdings {
            costs[holding.id] = holding.averageCostPerUnit
        }

        return sales.reduce(Decimal.zero) { total, sale in
            guard let holdingID = sale.holdingID, let costPerUnit = costs[holdingID] else {
                return total
            }

            return total + sale.realizedProfitLoss(costPerUnit: costPerUnit)
        }
    }

    /// What sales did to one account's balance: the proceeds of every sale that
    /// paid into it.
    ///
    /// Only ever positive. A sale is the one side of this app's cash flow that
    /// cannot reverse, because unwinding one means deleting it.
    /// What selling paid into this account.
    ///
    /// A swap is skipped, because nothing was paid into anything: one coin
    /// became another and the value never left the portfolio. Counting it here
    /// would credit an account with đồng that does not exist, while the coin
    /// bought still carries its value — net worth would double-count the trade.
    static func netFlow(for account: CashAccount, sales: [FundSale]) -> Decimal {
        sales.reduce(Decimal.zero) { total, sale in
            guard !sale.isSwap, sale.proceedsAccountID == account.id else {
                return total
            }
            return total + sale.proceeds
        }
    }

    /// Every sale that paid into this account, which is what the account
    /// deletion guard counts. A swap paid into no account, so it never holds
    /// one open.
    static func count(for account: CashAccount, sales: [FundSale]) -> Int {
        sales.filter { !$0.isSwap && $0.proceedsAccountID == account.id }.count
    }

    /// Every sale out of every lot held in one instrument, newest first. What
    /// the group screen lists under the positions themselves.
    static func sales(
        forInstrumentID instrumentID: UUID?,
        holdings: [FundHolding],
        sales: [FundSale]
    ) -> [FundSale] {
        let lots = Set(
            holdings
                .filter { $0.instrumentID == instrumentID }
                .map(\.id)
        )

        return
            sales
            .filter { $0.holdingID.map(lots.contains) == true }
            .sorted { $0.soldAt > $1.soldAt }
    }

    /// The sales belonging to these lots and no others. Lets a caller hand a
    /// filtered slice of the portfolio to the maths above without the sales of
    /// everything else riding along.
    static func sales(of holdings: [FundHolding], sales: [FundSale]) -> [FundSale] {
        let lots = Set(holdings.map(\.id))
        return sales.filter { $0.holdingID.map(lots.contains) == true }
    }
}
