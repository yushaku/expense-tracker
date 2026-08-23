import Foundation

enum CashBalanceSummary {
    static func total(of accounts: [CashAccount]) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + account.openingBalance
        }
    }

    /// Principal currently locked in savings deposits funded from this account.
    static func fundedAmount(for account: CashAccount, deposits: [SavingsDeposit]) -> Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            deposit.sourceAccountID == account.id ? total + deposit.principal : total
        }
    }

    /// Opening balance minus the principal moved into savings deposits.
    static func available(for account: CashAccount, deposits: [SavingsDeposit]) -> Decimal {
        account.openingBalance - fundedAmount(for: account, deposits: deposits)
    }

    static func totalAvailable(
        of accounts: [CashAccount],
        deposits: [SavingsDeposit]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + available(for: account, deposits: deposits)
        }
    }
}
