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
    /// worth today. Money moved from an account into a deposit or a holding is
    /// already removed from the spendable side, so it is counted once; a holding
    /// contributes its market value, so an unrealized gain shows up as growth.
    static func netWorth(
        accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding]
    ) -> Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            deposits: deposits,
            holdings: holdings
        )
            + totalPrincipal(of: deposits)
            + FundSummary.totalMarketValue(of: holdings)
    }
}
