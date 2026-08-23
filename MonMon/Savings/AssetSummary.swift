import Foundation

enum AssetSummary {
    static func totalPrincipal(of deposits: [SavingsDeposit]) -> Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            total + deposit.principal
        }
    }

    static func totalProjectedInterest(of deposits: [SavingsDeposit]) -> Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            total + deposit.projectedInterest
        }
    }

    static func totalMaturityValue(of deposits: [SavingsDeposit]) -> Decimal {
        totalPrincipal(of: deposits) + totalProjectedInterest(of: deposits)
    }

    /// Spendable cash, plus deposited principal, plus what the fund holdings are
    /// worth today, plus what is still owed to the owner, minus what the owner
    /// still owes. Money moved from an account into a deposit or a holding is
    /// already removed from the spendable side, so it is counted once; a holding
    /// contributes its market value, so an unrealized gain shows up as growth.
    /// Recorded income and expense reach this figure through the spendable side,
    /// so an expense lowers net worth by exactly its amount. An internal
    /// transfer leaves it untouched: it only moves money between two accounts
    /// that both already count here.
    ///
    /// Debts leave it untouched too, and for a subtler reason. Borrowing raises
    /// the spendable side and raises what is owed by the same amount; lending
    /// lowers the spendable side and raises what is owed to the owner by the
    /// same amount; a payment moves both back together. Only recording a debt
    /// that names no account moves this figure, and that is correct: stating a
    /// previously untracked obligation makes the owner poorer on paper.
    ///
    /// Money lent out counts at what is outstanding while a deposit counts at
    /// its principal. That is not an inconsistency: a deposit's principal sits
    /// untouched until maturity, whereas the repaid part of a loan has already
    /// landed back in cash and would otherwise be counted twice. Projected
    /// interest is left out of both.
    static func netWorth(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        instruments: [FundInstrument],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment]
    ) -> Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )
            + totalPrincipal(of: deposits)
            + FundSummary.totalMarketValue(of: holdings, instruments: instruments)
            + DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .lent)
            - DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .borrowed)
    }
}
