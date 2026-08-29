import Foundation
import SwiftData

@Model
final class MoneyTransaction {
    var id: UUID = UUID()
    var kind: TransactionKind = TransactionKind.expense
    /// Always positive. `kind` carries the direction.
    var amount: Decimal = Decimal.zero
    var occurredAt: Date = Date(timeIntervalSince1970: 0)
    var note: String = ""
    /// Identifier of the cash account this money moved through. Required: a
    /// transaction with no account cannot move a balance, which is the only
    /// thing this module exists to do.
    var accountID: UUID = AccountSeed.unassignedID
    /// Optional so a half-finished category deletion cannot destroy a
    /// transaction. The UI renders a missing category as "Uncategorized".
    var categoryID: UUID?
    /// The recurring rule that generated this transaction, or `nil` when the
    /// owner typed it. It is provenance for the badge on the card, and the key
    /// `RecurringGenerator` and `StoreReconciler` both dedupe on: one rule may
    /// only ever produce one transaction per day.
    var sourceRuleID: UUID?
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    /// SHA-256 fingerprint of the statement candidate that created this
    /// transaction. `nil` means the record was created outside statement
    /// import or predates provenance tracking.
    var sourceImportID: String? = nil
    /// Frozen, versioned explanation of how an income was assigned across
    /// budget jars when it was recorded. Optional for legacy rows and expenses.
    var incomeAllocationSnapshot: String? = nil

    init(
        id: UUID,
        kind: TransactionKind,
        amount: Decimal,
        occurredAt: Date,
        note: String,
        accountID: UUID,
        categoryID: UUID?,
        sourceRuleID: UUID?,
        currencyCode: String,
        createdAt: Date,
        sourceImportID: String? = nil,
        incomeAllocationSnapshot: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.sourceRuleID = sourceRuleID
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.sourceImportID = sourceImportID
        self.incomeAllocationSnapshot = incomeAllocationSnapshot
    }
}

extension MoneyTransaction {
    /// Positive for income, negative for expense.
    var signedAmount: Decimal {
        switch kind {
        case .income:
            amount
        case .expense:
            -amount
        }
    }
}
