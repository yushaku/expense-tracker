import Foundation

/// One wedge of the per-account doughnut on the Accounts screen.
///
/// The Home ring splits money by what it is doing — cash, savings, funds, lent
/// out. This one splits the cash half again by where it sits, which is the only
/// question the Accounts screen is asked.
struct AccountBalanceSlice: Identifiable, Equatable {
    let accountID: UUID
    let name: String
    let kind: CashAccountKind
    let amount: Decimal

    var id: UUID { accountID }
}

enum AccountBalanceAllocation {
    /// The wedges to draw, largest first.
    ///
    /// Overdrawn accounts are left out for the same reason the Home ring leaves
    /// out debt: a doughnut cannot draw a negative wedge, and drawing one by
    /// magnitude would make an overdraft look like money in hand. Their total is
    /// reported separately by `overdraft(...)`.
    static func slices(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        withdrawals: [SavingsWithdrawal],
        holdings: [FundHolding],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> [AccountBalanceSlice] {
        accounts
            .map { account in
                AccountBalanceSlice(
                    accountID: account.id,
                    name: account.name,
                    kind: account.kind,
                    amount: CashBalanceSummary.available(
                        for: account,
                        deposits: deposits,
                        holdings: holdings,
                        withdrawals: withdrawals,
                        transactions: transactions,
                        transfers: transfers,
                        debts: debts,
                        payments: payments,
                        sales: sales
                    )
                )
            }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    static func total(of slices: [AccountBalanceSlice]) -> Decimal {
        slices.reduce(Decimal.zero) { total, slice in
            total + slice.amount
        }
    }

    /// Share of the ring, in percent, rounded the way every other chart in the
    /// app rounds it.
    static func percent(of amount: Decimal, in total: Decimal) -> Decimal {
        Percentage.share(of: amount, in: total)
    }
}
