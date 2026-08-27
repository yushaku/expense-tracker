import Foundation

enum CashBalanceSummary {
    /// A credit card's limit is borrowing capacity, not owner cash. The ledger
    /// balance is negative while money is owed, so adding it to the limit gives
    /// the amount still available without changing any wealth calculation.
    static func availableCredit(limit: Decimal, currentBalance: Decimal) -> Decimal {
        max(.zero, limit + currentBalance)
    }

    static func total(of accounts: [CashAccount]) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + account.openingBalance
        }
    }

    /// Money moved out of this account and still tied up elsewhere: the principal
    /// of every savings deposit it funded plus the cost basis of every fund
    /// holding it bought. `holdings` has no default value on purpose — a
    /// forgotten argument would silently overstate the spendable balance.
    static func fundedAmount(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        holdings: [FundHolding]
    ) -> Decimal {
        let depositedPrincipal = deposits.reduce(Decimal.zero) { total, deposit in
            deposit.sourceAccountID == account.id ? total + deposit.principal : total
        }

        return holdings.reduce(depositedPrincipal) { total, holding in
            holding.sourceAccountID == account.id ? total + holding.costBasis : total
        }
    }

    /// Where tracking started, plus the recorded cash flow, plus what internal
    /// transfers moved in or out, plus what debts and their payments moved, plus
    /// what selling a position paid back in, minus the money moved into savings
    /// deposits and funds. `openingBalance` is never rewritten; every later
    /// change is derived.
    ///
    /// A sale is added rather than netted against `fundedAmount`, and that pair
    /// is what makes closing a position come out right. `fundedAmount` keeps
    /// subtracting the lot's original cost, because that is the money that
    /// genuinely left on the day it was bought and no later event changes it;
    /// the sale adds what came back. Over a full round trip the account moves by
    /// the realized profit alone, which is why selling never has to rewrite the
    /// lot it came out of.
    ///
    /// Like `holdings`, none of the collections has a default value, and the
    /// reason has grown teeth: a forgotten argument would silently misreport the
    /// spendable balance, and every source-balance guard in the app now reads
    /// this figure, so the app would permit an overdraft while claiming it had
    /// checked.
    ///
    /// Debt flow needs its own term rather than riding on `fundedAmount`: a
    /// deposit only ever removes cash, whereas borrowing adds it.
    static func available(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        account.openingBalance
            + TransactionSummary.netFlow(for: account, transactions: transactions)
            + TransferSummary.netFlow(for: account, transfers: transfers)
            + DebtSummary.netFlow(for: account, debts: debts, payments: payments)
            + FundSaleSummary.netFlow(for: account, sales: sales)
            + SavingsWithdrawalSummary.netFlow(for: account, withdrawals: withdrawals)
            - fundedAmount(for: account, deposits: deposits, holdings: holdings)
    }

    /// Transfers cancel out here: one account's outflow is another's inflow, so
    /// moving money between two of the owner's accounts leaves this total alone.
    ///
    /// Debt flow does not cancel out, because the counterparty lives outside the
    /// app: borrowing genuinely adds cash the owner did not have. That is why
    /// `AssetSummary.netWorth` subtracts what is still owed rather than stopping
    /// at this figure.
    static func totalAvailable(
        of accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total
                + available(
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
        }
    }
}
