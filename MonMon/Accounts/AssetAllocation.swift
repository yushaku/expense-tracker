import Foundation

/// One wedge of the assets doughnut on the Home screen.
struct AssetAllocationSlice: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case cash
        case savings
        case funds
        /// Declared last because the first three are money the owner holds,
        /// while this is a claim on money someone else holds.
        case lent

        var displayName: String {
            switch self {
            case .cash:
                "Cash"
            case .savings:
                "Savings"
            case .funds:
                "Funds"
            case .lent:
                "Lent out"
            }
        }
    }

    let kind: Kind
    let amount: Decimal

    var id: String { kind.rawValue }
}

/// Splits what the owner holds into the four groups `AssetSummary.netWorth`
/// adds up, so the doughnut and the total can never disagree.
///
/// A doughnut cannot draw a negative wedge, and drawing one by magnitude would
/// make debt look like an asset. Overdrawn accounts — a credit card, or cash
/// spent past the balance — are therefore kept out of the ring, and so is money
/// the owner borrowed. Both are reported together by `liabilities(...)`. Net
/// worth still subtracts them:
/// `netWorth == total(of: slices) − liabilities`.
///
/// Money lent out is the opposite case and does get a wedge: it is an asset the
/// owner holds a claim to but cannot spend, and leaving it undrawn would put the
/// ring and its centre figure out of step by exactly the amount lent.
enum AssetAllocation {
    /// The wedges to draw, largest first, with empty groups dropped so the ring
    /// never carries a zero-width slice.
    static func slices(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment]
    ) -> [AssetAllocationSlice] {
        let candidates = [
            AssetAllocationSlice(
                kind: .cash,
                amount: positiveCash(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    transactions: transactions,
                    transfers: transfers,
                    debts: debts,
                    payments: payments
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
            AssetAllocationSlice(
                kind: .lent,
                amount: DebtSummary.totalOutstanding(
                    of: debts,
                    payments: payments,
                    direction: .lent
                )
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
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            let available = CashBalanceSummary.available(
                for: account,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions,
                transfers: transfers,
                debts: debts,
                payments: payments
            )

            return available > 0 ? total + available : total
        }
    }

    /// What the overdrawn accounts owe, as a positive magnitude. Zero when
    /// nothing is overdrawn.
    ///
    /// Named `overdraft` rather than `debt` because a `Debt` is now a record the
    /// owner keeps, and a function meaning something narrower beside a model of
    /// that name is a trap. `liabilities(...)` is the figure that means all of
    /// it.
    static func overdraft(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            let available = CashBalanceSummary.available(
                for: account,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions,
                transfers: transfers,
                debts: debts,
                payments: payments
            )

            return available < 0 ? total - available : total
        }
    }

    /// Everything the owner owes, as a positive magnitude: the overdrawn
    /// accounts plus what is still outstanding on money borrowed. This is the
    /// figure the ring subtracts, and the two sources never overlap — an
    /// overdrawn card and a loan from a relative are separate obligations.
    static func liabilities(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Decimal {
        overdraft(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )
            + DebtSummary.totalOutstanding(
                of: debts,
                payments: payments,
                direction: .borrowed
            )
    }

    static func total(of slices: [AssetAllocationSlice]) -> Decimal {
        slices.reduce(Decimal.zero) { total, slice in
            total + slice.amount
        }
    }

    /// Share of the ring, in percent. Shared with every other chart through
    /// `Percentage`, so they all round the same way.
    static func percent(of amount: Decimal, in total: Decimal) -> Decimal {
        Percentage.share(of: amount, in: total)
    }
}
