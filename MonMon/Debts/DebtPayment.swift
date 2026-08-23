import Foundation
import SwiftData

/// One payment against a `Debt`. It moves cash the opposite way the debt opened,
/// so it is not income and not an expense: paying back what was borrowed does
/// not make the owner poorer, it swaps a liability for cash already counted.
/// Like `AccountTransfer` it carries no category and stays out of the Spending
/// totals.
@Model
final class DebtPayment {
    var id: UUID = UUID()
    /// Identifier of the debt this pays down. Required, and unlike
    /// `MoneyTransaction.categoryID` it cannot be optional: the direction that
    /// signs this amount lives on the debt, so an orphan payment is not merely
    /// untidy, it is uncomputable. Deleting a debt therefore deletes its
    /// payments with it.
    var debtID: UUID
    /// Always positive. The debt's `direction` carries the direction.
    var amount: Decimal = Decimal.zero
    var occurredAt: Date = Date(timeIntervalSince1970: 0)
    /// Identifier of the cash account the money moved through. Required, unlike
    /// `Debt.accountID`: a payment that moves no cash is not a payment, it is a
    /// smaller principal, and that is an edit to the debt.
    var accountID: UUID
    var note: String = ""
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        debtID: UUID,
        amount: Decimal,
        occurredAt: Date,
        accountID: UUID,
        note: String,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.debtID = debtID
        self.amount = amount
        self.occurredAt = occurredAt
        self.accountID = accountID
        self.note = note
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

extension DebtPayment {
    /// What this payment does to the account it names, given which way its debt
    /// points: negative when repaying something borrowed, positive when being
    /// repaid on something lent. The direction is passed in rather than stored,
    /// so a payment and its debt can never disagree about it.
    func signedAmount(for direction: DebtDirection) -> Decimal {
        -amount * direction.openingSign
    }
}
