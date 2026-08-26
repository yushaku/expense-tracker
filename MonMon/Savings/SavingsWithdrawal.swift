import Foundation
import SwiftData

/// One movement out of a savings deposit and into a cash account.
///
/// The original deposit is never rewritten. Keeping withdrawals as dated
/// records preserves asset history and lets a correction be edited or deleted
/// without inventing a second source of truth for the opening principal.
@Model
final class SavingsWithdrawal {
    var id: UUID = UUID()
    var depositID: UUID?
    var principal: Decimal = Decimal.zero
    var amountReceived: Decimal = Decimal.zero
    var destinationAccountID: UUID = AccountSeed.unassignedID
    var withdrawnAt: Date = Date(timeIntervalSince1970: 0)
    var note: String = ""
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        depositID: UUID?,
        principal: Decimal,
        amountReceived: Decimal,
        destinationAccountID: UUID,
        withdrawnAt: Date,
        note: String = "",
        currencyCode: String = VNDCurrency.code,
        createdAt: Date
    ) {
        self.id = id
        self.depositID = depositID
        self.principal = principal
        self.amountReceived = amountReceived
        self.destinationAccountID = destinationAccountID
        self.withdrawnAt = withdrawnAt
        self.note = note
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

extension SavingsWithdrawal {
    var realizedInterest: Decimal {
        amountReceived - principal
    }
}
