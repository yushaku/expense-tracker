import Foundation

enum AccountLinkedSourceKind: CaseIterable, Identifiable {
    case savings
    case funds
    case debts
    case recurring

    var id: Self { self }
}

struct AccountLinkedSourceRow: Equatable, Identifiable {
    let kind: AccountLinkedSourceKind
    let count: Int

    var id: AccountLinkedSourceKind { kind }
}

enum AccountLinkedSourceSummary {
    static func rows(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        withdrawals: [SavingsWithdrawal],
        holdings: [FundHolding],
        sales: [FundSale],
        debts: [Debt],
        payments: [DebtPayment],
        recurringRules: [RecurringRule]
    ) -> [AccountLinkedSourceRow] {
        let counts: [AccountLinkedSourceKind: Int] = [
            .savings: deposits.count { $0.sourceAccountID == account.id }
                + withdrawals.count { $0.destinationAccountID == account.id },
            // A swap paid into no account, so it is not a reason this one
            // cannot be deleted. See `FundSale.swapHoldingID`.
            .funds: holdings.count { $0.sourceAccountID == account.id }
                + sales.count { !$0.isSwap && $0.proceedsAccountID == account.id },
            .debts: debts.count { $0.accountID == account.id }
                + payments.count { $0.accountID == account.id },
            .recurring: recurringRules.count { $0.accountID == account.id },
        ]

        return AccountLinkedSourceKind.allCases.compactMap { kind in
            guard let count = counts[kind], count > 0 else {
                return nil
            }
            return AccountLinkedSourceRow(kind: kind, count: count)
        }
    }
}
