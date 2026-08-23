import Foundation

enum TransactionFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case missingCategory
}

struct TransactionDraft: Equatable {
    var kind: TransactionKind
    var amountText: String
    var occurredAt: Date
    var note: String
    var accountID: UUID?
    var categoryID: UUID?

    init(
        kind: TransactionKind = .expense,
        amountText: String = "",
        occurredAt: Date,
        note: String = "",
        accountID: UUID? = nil,
        categoryID: UUID? = nil
    ) {
        self.kind = kind
        self.amountText = amountText
        self.occurredAt = occurredAt
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
    }

    init(transaction: MoneyTransaction) {
        self.init(
            kind: transaction.kind,
            amountText: VNDCurrency.formatPlain(transaction.amount),
            occurredAt: transaction.occurredAt,
            note: transaction.note,
            accountID: transaction.accountID,
            categoryID: transaction.categoryID
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var kind: TransactionKind
        var amount: Decimal
        var occurredAt: Date
        var note: String
        var accountID: UUID
        var categoryID: UUID
    }

    /// The amount is always validated positive; `kind` alone carries direction,
    /// so nothing downstream has to agree on a sign convention.
    func validate() throws -> ValidatedValues {
        guard let amount = VNDCurrency.parse(amountText) else {
            throw TransactionFormError.invalidAmount
        }

        guard amount > 0 else {
            throw TransactionFormError.nonPositiveAmount
        }

        guard let accountID else {
            throw TransactionFormError.missingAccount
        }

        guard let categoryID else {
            throw TransactionFormError.missingCategory
        }

        return ValidatedValues(
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: accountID,
            categoryID: categoryID
        )
    }

    func makeTransaction(id: UUID, createdAt: Date) throws -> MoneyTransaction {
        let values = try validate()

        return MoneyTransaction(
            id: id,
            kind: values.kind,
            amount: values.amount,
            occurredAt: values.occurredAt,
            note: values.note,
            accountID: values.accountID,
            categoryID: values.categoryID,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    func apply(to transaction: MoneyTransaction) throws {
        let values = try validate()

        transaction.kind = values.kind
        transaction.amount = values.amount
        transaction.occurredAt = values.occurredAt
        transaction.note = values.note
        transaction.accountID = values.accountID
        transaction.categoryID = values.categoryID
    }
}
