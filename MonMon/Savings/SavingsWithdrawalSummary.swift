import Foundation

enum SavingsDepositStatus: Equatable {
    case active
    case matured
    case settled
}

/// Derives the live savings position and its cash flow from immutable deposits
/// plus dated withdrawals.
enum SavingsWithdrawalSummary {
    static func withdrawals(
        for deposit: SavingsDeposit,
        withdrawals: [SavingsWithdrawal]
    ) -> [SavingsWithdrawal] {
        withdrawals
            .filter { $0.depositID == deposit.id }
            .sorted { $0.withdrawnAt > $1.withdrawnAt }
    }

    static func principalWithdrawn(
        from deposit: SavingsDeposit,
        withdrawals: [SavingsWithdrawal]
    ) -> Decimal {
        withdrawals.reduce(Decimal.zero) { total, withdrawal in
            withdrawal.depositID == deposit.id ? total + withdrawal.principal : total
        }
    }

    static func remainingPrincipal(
        of deposit: SavingsDeposit,
        withdrawals: [SavingsWithdrawal]
    ) -> Decimal {
        deposit.principal - principalWithdrawn(from: deposit, withdrawals: withdrawals)
    }

    static func realizedInterest(
        for deposit: SavingsDeposit,
        withdrawals: [SavingsWithdrawal]
    ) -> Decimal {
        withdrawals.reduce(Decimal.zero) { total, withdrawal in
            withdrawal.depositID == deposit.id ? total + withdrawal.realizedInterest : total
        }
    }

    static func netFlow(
        for account: CashAccount,
        withdrawals: [SavingsWithdrawal]
    ) -> Decimal {
        withdrawals.reduce(Decimal.zero) { total, withdrawal in
            withdrawal.destinationAccountID == account.id
                ? total + withdrawal.amountReceived : total
        }
    }

    static func count(for account: CashAccount, withdrawals: [SavingsWithdrawal]) -> Int {
        withdrawals.filter { $0.destinationAccountID == account.id }.count
    }

    /// Keeps the books needing attention at the top and completed history at
    /// the bottom. Within a state, the nearest maturity date comes first.
    static func sortedDeposits(
        _ deposits: [SavingsDeposit],
        withdrawals: [SavingsWithdrawal],
        asOf: Date
    ) -> [SavingsDeposit] {
        deposits.sorted { lhs, rhs in
            let lhsRank = rank(lhs.status(withdrawals: withdrawals, asOf: asOf))
            let rhsRank = rank(rhs.status(withdrawals: withdrawals, asOf: asOf))

            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            if lhs.maturityDate != rhs.maturityDate {
                return lhs.maturityDate < rhs.maturityDate
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private static func rank(_ status: SavingsDepositStatus) -> Int {
        switch status {
        case .matured:
            0
        case .active:
            1
        case .settled:
            2
        }
    }
}

extension SavingsDeposit {
    func remainingPrincipal(withdrawals: [SavingsWithdrawal]) -> Decimal {
        SavingsWithdrawalSummary.remainingPrincipal(of: self, withdrawals: withdrawals)
    }

    func status(withdrawals: [SavingsWithdrawal], asOf: Date) -> SavingsDepositStatus {
        if remainingPrincipal(withdrawals: withdrawals) <= 0 {
            return .settled
        }

        return asOf >= maturityDate ? .matured : .active
    }

    func projectedInterest(withdrawals: [SavingsWithdrawal]) -> Decimal {
        SavingsInterest.projectedInterest(
            principal: remainingPrincipal(withdrawals: withdrawals),
            annualRatePercent: annualInterestRate,
            days: termDayCount
        )
    }

    func maturityValue(withdrawals: [SavingsWithdrawal]) -> Decimal {
        remainingPrincipal(withdrawals: withdrawals)
            + projectedInterest(withdrawals: withdrawals)
    }
}
