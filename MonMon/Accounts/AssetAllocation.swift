import Foundation

/// One wedge of the assets doughnut on the Home screen.
struct AssetAllocationSlice: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case cash
        case savings
        case funds

        var displayName: String {
            switch self {
            case .cash:
                "Cash"
            case .savings:
                "Savings"
            case .funds:
                "Funds"
            }
        }
    }

    let kind: Kind
    let amount: Decimal

    var id: String { kind.rawValue }
}

/// Splits what the owner holds into the three groups `AssetSummary.netWorth`
/// adds up, so the doughnut and the total can never disagree.
///
/// A doughnut cannot draw a negative wedge, and drawing one by magnitude would
/// make debt look like an asset. Overdrawn accounts — a credit card, or cash
/// spent past the balance — are therefore kept out of the ring and reported
/// separately by `debt(...)`. Net worth still subtracts them:
/// `netWorth == total(of: slices) − debt`.
enum AssetAllocation {
    /// The wedges to draw, largest first, with empty groups dropped so the ring
    /// never carries a zero-width slice.
    static func slices(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction]
    ) -> [AssetAllocationSlice] {
        let candidates = [
            AssetAllocationSlice(
                kind: .cash,
                amount: positiveCash(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    transactions: transactions
                )
            ),
            AssetAllocationSlice(
                kind: .savings,
                amount: AssetSummary.totalPrincipal(of: deposits)
            ),
            AssetAllocationSlice(
                kind: .funds,
                amount: FundSummary.totalMarketValue(of: holdings)
            ),
        ]

        return
            candidates
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    /// Spendable cash across accounts that are not overdrawn.
    static func positiveCash(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            let available = CashBalanceSummary.available(
                for: account,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions
            )

            return available > 0 ? total + available : total
        }
    }

    /// What the overdrawn accounts owe, as a positive magnitude. Zero when
    /// nothing is overdrawn.
    static func debt(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            let available = CashBalanceSummary.available(
                for: account,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions
            )

            return available < 0 ? total - available : total
        }
    }

    static func total(of slices: [AssetAllocationSlice]) -> Decimal {
        slices.reduce(Decimal.zero) { total, slice in
            total + slice.amount
        }
    }

    /// Share of the ring, in percent, rounded to one decimal place. Zero when
    /// there is nothing to divide by, so an empty portfolio never divides by
    /// zero.
    static func percent(of amount: Decimal, in total: Decimal) -> Decimal {
        guard total > 0 else {
            return .zero
        }

        var input = amount / total * 100
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 1, .plain)
        return result
    }
}
