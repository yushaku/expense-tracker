import Foundation
import SwiftData

/// The models the store is built from.
///
/// ## Why every attribute carries a default
///
/// CloudKit requires each attribute to be optional or to have a default value,
/// so `icloud-sync` cannot begin against a schema that has neither. The defaults
/// are declared now, while the store is still disposable, rather than as part of
/// the change that turns synchronisation on.
///
/// None of them is reachable through the app: every initialiser takes every
/// value, and every write goes through a draft that validated it first. They
/// exist for the one case the app cannot control — a record materialised by a
/// peer that was written against a schema this build does not have the field in.
/// They are chosen to be **visibly wrong** rather than plausible for exactly
/// that reason: a date defaults to the epoch and a name to the empty string, so
/// a record that ever shows one is obviously a record to look at, not a record
/// to trust.
enum MonMonSchema {
    /// Registered in the container and in every in-memory test container, so the
    /// two can never drift apart.
    static var models: [any PersistentModel.Type] {
        [
            CashAccount.self, SavingsDeposit.self, SavingsWithdrawal.self,
            FundInstrument.self, FundHolding.self, FundSale.self,
            TransactionCategory.self, MoneyTransaction.self, PendingTransactionCapture.self,
            AccountTransfer.self,
            Debt.self, DebtPayment.self,
            RecurringRule.self,
        ]
    }
}
