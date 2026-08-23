import Foundation
import SwiftData

@Model
final class MoneyTransaction {
    var id: UUID
    var kind: TransactionKind
    /// Always positive. `kind` carries the direction.
    var amount: Decimal
    var occurredAt: Date
    var note: String
    /// Identifier of the cash account this money moved through. Required: a
    /// transaction with no account cannot move a balance, which is the only
    /// thing this module exists to do.
    var accountID: UUID
    /// Optional so a half-finished category deletion cannot destroy a
    /// transaction. The UI renders a missing category as "Uncategorized".
    var categoryID: UUID?
    var currencyCode: String
    var createdAt: Date

    init(
        id: UUID,
        kind: TransactionKind,
        amount: Decimal,
        occurredAt: Date,
        note: String,
        accountID: UUID,
        categoryID: UUID?,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.currencyCode = currencyCode
        self.createdAt = createdAt
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
