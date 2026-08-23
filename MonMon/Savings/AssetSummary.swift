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

    /// Spendable cash plus deposited principal. Money moved from an account into
    /// a deposit is already removed from the spendable side, so it is counted once.
    static func netWorth(accounts: [CashAccount], deposits: [SavingsDeposit]) -> Decimal {
        CashBalanceSummary.totalAvailable(of: accounts, deposits: deposits)
            + totalPrincipal(of: deposits)
    }
}
