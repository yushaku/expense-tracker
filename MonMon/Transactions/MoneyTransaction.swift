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
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

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
