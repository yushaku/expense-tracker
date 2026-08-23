import Foundation
import SwiftData

enum MonMonSchema {
    /// Registered in the container and in every in-memory test container, so the
    /// two can never drift apart.
    static var models: [any PersistentModel.Type] {
        [
            CashAccount.self, SavingsDeposit.self,
            FundInstrument.self, FundHolding.self,
            TransactionCategory.self, MoneyTransaction.self, AccountTransfer.self,
            Debt.self, DebtPayment.self,
        ]
    }
}
