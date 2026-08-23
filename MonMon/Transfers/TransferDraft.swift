import Foundation

enum TransferFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingSourceAccount
    case missingDestinationAccount
    case sameAccount
    case insufficientSourceBalance
}

struct TransferDraft: Equatable {
    var amountText: String
    var occurredAt: Date
    var note: String
    var sourceAccountID: UUID?
    var destinationAccountID: UUID?

    init(
        amountText: String = "",
        occurredAt: Date,
        note: String = "",
        sourceAccountID: UUID? = nil,
        destinationAccountID: UUID? = nil
    ) {
        self.amountText = amountText
        self.occurredAt = occurredAt
        self.note = note
        self.sourceAccountID = sourceAccountID
        self.destinationAccountID = destinationAccountID
    }

    init(transfer: AccountTransfer) {
        self.init(
            amountText: VNDCurrency.formatPlain(transfer.amount),
            occurredAt: transfer.occurredAt,
            note: transfer.note,
            sourceAccountID: transfer.sourceAccountID,
            destinationAccountID: transfer.destinationAccountID
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var amount: Decimal
        var occurredAt: Date
        var note: String
        var sourceAccountID: UUID
        var destinationAccountID: UUID
    }

    /// The amount is always validated positive; the pair of accounts alone
    /// carries direction. The two ends must differ — a transfer onto itself
    /// moves nothing and would only clutter the ledger.
    ///
    /// - Parameter availableSourceBalance: spendable balance of the account the
    ///   money leaves, or `nil` when no account is picked yet or the account is
    ///   allowed to go negative, as a credit card is. When editing, the caller
    ///   adds this transfer's current amount back so re-saving an unchanged
    ///   amount never reports an overdraft.
    func validate(availableSourceBalance: Decimal?) throws -> ValidatedValues {
        guard let amount = VNDCurrency.parse(amountText) else {
            throw TransferFormError.invalidAmount
        }

        guard amount > 0 else {
            throw TransferFormError.nonPositiveAmount
        }

        guard let sourceAccountID else {
            throw TransferFormError.missingSourceAccount
        }

        guard let destinationAccountID else {
            throw TransferFormError.missingDestinationAccount
        }

        guard sourceAccountID != destinationAccountID else {
            throw TransferFormError.sameAccount
        }

        if let availableSourceBalance, amount > availableSourceBalance {
            throw TransferFormError.insufficientSourceBalance
        }

        return ValidatedValues(
            amount: amount,
            occurredAt: occurredAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID
        )
    }

    func makeTransfer(
        id: UUID,
        createdAt: Date,
        availableSourceBalance: Decimal?
    ) throws -> AccountTransfer {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        return AccountTransfer(
            id: id,
            amount: values.amount,
            occurredAt: values.occurredAt,
            note: values.note,
            sourceAccountID: values.sourceAccountID,
            destinationAccountID: values.destinationAccountID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    func apply(to transfer: AccountTransfer, availableSourceBalance: Decimal?) throws {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        transfer.amount = values.amount
        transfer.occurredAt = values.occurredAt
        transfer.note = values.note
        transfer.sourceAccountID = values.sourceAccountID
        transfer.destinationAccountID = values.destinationAccountID
    }

    /// Swaps the two ends, so a wrong-way transfer is one tap from right.
    mutating func swapEnds() {
        (sourceAccountID, destinationAccountID) = (destinationAccountID, sourceAccountID)
    }
}
