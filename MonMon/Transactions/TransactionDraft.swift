import Foundation

enum TransactionFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case missingCategory
}

enum TransactionDefaults {
    static let accountStorageKey = "defaultTransactionAccountID"
    static let categoryStorageKey = "defaultTransactionCategoryID"

    /// A missing preference means first run and resolves to starter data. Once
    /// an id has been stored, it must still name a current record; stale ids do
    /// not silently switch the owner to a different account or category.
    static func apply(
        accountValue: String,
        categoryValue: String,
        accounts: [CashAccount],
        categories: [TransactionCategory],
        to draft: inout TransactionDraft
    ) {
        draft.kind = .expense
        draft.accountID = resolveAccountID(accountValue, accounts: accounts)
        draft.categoryID = resolveCategoryID(categoryValue, categories: categories)
    }

    static func resolveAccountID(
        _ value: String,
        accounts: [CashAccount]
    ) -> UUID? {
        if value.isEmpty {
            return accounts.first { $0.id == AccountSeed.defaultBankID }?.id
                ?? accounts.first {
                    $0.name == AccountSeed.defaultBankName && $0.kind == .bank
                }?.id
        }

        guard let id = UUID(uuidString: value) else {
            return nil
        }

        return accounts.first { $0.id == id }?.id
    }

    static func resolveCategoryID(
        _ value: String,
        categories: [TransactionCategory]
    ) -> UUID? {
        if value.isEmpty {
            return categories.first {
                $0.name == CategorySeed.defaultExpenseName && $0.kind == .expense
            }?.id
        }

        guard let id = UUID(uuidString: value) else {
            return nil
        }

        return categories.first { $0.id == id && $0.kind == .expense }?.id
    }
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
            sourceRuleID: nil,
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
