import Foundation
import SwiftData

/// Money moved between two of the owner's own accounts. It is not income and
/// not an expense: nothing enters or leaves the owner's money, so a transfer
/// carries no category and never reaches the Spending totals.
@Model
final class AccountTransfer {
    var id: UUID = UUID()
    /// Always positive. The pair of accounts carries the direction, so no call
    /// site has to agree on a sign convention.
    var amount: Decimal = Decimal.zero
    var occurredAt: Date = Date(timeIntervalSince1970: 0)
    var note: String = ""
    /// Identifier of the account the money left. Required: a transfer with no
    /// source moves nothing.
    var sourceAccountID: UUID = AccountSeed.unassignedID
    /// Identifier of the account the money reached. Required, and validated to
    /// differ from the source.
    var destinationAccountID: UUID = AccountSeed.unassignedID
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        amount: Decimal,
        occurredAt: Date,
        note: String,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.sourceAccountID = sourceAccountID
        self.destinationAccountID = destinationAccountID
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

extension AccountTransfer {
    /// What this transfer does to one account's balance: negative on the way
    /// out, positive on the way in, and zero for every other account.
    func signedAmount(for accountID: UUID) -> Decimal {
        switch accountID {
        case sourceAccountID:
            -amount
        case destinationAccountID:
            amount
        default:
            .zero
        }
    }
}
