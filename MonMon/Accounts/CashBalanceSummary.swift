import Foundation

enum CashBalanceSummary {
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

    /// Where tracking started, plus the recorded cash flow, minus the money
    /// moved into savings deposits and funds. `openingBalance` is never
    /// rewritten; every later change is derived. Like `holdings`, `transactions`
    /// has no default value on purpose — a forgotten argument would silently
    /// misreport the spendable balance.
    static func available(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction]
    ) -> Decimal {
        account.openingBalance
            + TransactionSummary.netFlow(for: account, transactions: transactions)
            - fundedAmount(for: account, deposits: deposits, holdings: holdings)
    }

    static func totalAvailable(
        of accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        transactions: [MoneyTransaction]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total
                + available(
                    for: account,
                    deposits: deposits,
                    holdings: holdings,
                    transactions: transactions
                )
        }
    }
}
