import Foundation

enum TransactionFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case missingCategory
    case tripRequiresExpense
    case jarOverrideRequiresTrip
}

enum TransactionDefaults {
    static let accountStorageKey = "defaultTransactionAccountID"
    /// The expense default. Named without a direction because it was stored
    /// before income had one of its own, and a stored key is never renamed.
    static let categoryStorageKey = "defaultTransactionCategoryID"
    static let incomeCategoryStorageKey = "defaultTransactionIncomeCategoryID"

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
                    $0.name == AccountSeed.defaultBankName && $0.kind == .normal
                }?.id
        }

        guard let id = UUID(uuidString: value) else {
            return nil
        }

        return accounts.first { $0.id == id }?.id
    }

    static func resolveCategoryID(
        _ value: String,
        categories: [TransactionCategory],
        kind: TransactionKind = .expense
    ) -> UUID? {
        if value.isEmpty {
            // By identity first, then by name. A store seeded before the starter
            // categories carried fixed ids still has its own, and a store seeded
            // in the other language has a name this would never match.
            return categories.first {
                $0.id == CategorySeed.defaultID(for: kind) && $0.kind == kind
            }?
            .id
                ?? categories.first {
                    $0.name == CategorySeed.defaultName(for: kind) && $0.kind == kind
                }?.id
        }

        guard let id = UUID(uuidString: value) else {
            return nil
        }

        return categories.first { $0.id == id && $0.kind == kind }?.id
    }

    /// The default for one direction. A form that switches between income and
    /// expense asks for the new direction's default rather than clearing the
    /// field, so the pair of preferences behaves like one.
    static func categoryID(
        for kind: TransactionKind,
        expenseValue: String,
        incomeValue: String,
        categories: [TransactionCategory]
    ) -> UUID? {
        switch kind {
        case .expense:
            resolveCategoryID(expenseValue, categories: categories, kind: .expense)
        case .income:
            resolveCategoryID(incomeValue, categories: categories, kind: .income)
        }
    }
}

struct TransactionDraft: Equatable {
    var kind: TransactionKind
    var amountText: String
    var occurredAt: Date
    var note: String
    var accountID: UUID?
    var categoryID: UUID?
    var tripWorkspaceID: UUID?
    var budgetJarOverrideID: UUID?

    init(
        kind: TransactionKind = .expense,
        amountText: String = "",
        occurredAt: Date,
        note: String = "",
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        tripWorkspaceID: UUID? = nil,
        budgetJarOverrideID: UUID? = nil
    ) {
        self.kind = kind
        self.amountText = amountText
        self.occurredAt = occurredAt
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.tripWorkspaceID = tripWorkspaceID
        self.budgetJarOverrideID = budgetJarOverrideID
    }

    init(transaction: MoneyTransaction) {
        self.init(
            kind: transaction.kind,
            amountText: VNDCurrency.formatPlain(transaction.amount),
            occurredAt: transaction.occurredAt,
            note: transaction.note,
            accountID: transaction.accountID,
            categoryID: transaction.categoryID,
            tripWorkspaceID: transaction.tripWorkspaceID,
            budgetJarOverrideID: transaction.budgetJarOverrideID
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
        var tripWorkspaceID: UUID?
        var budgetJarOverrideID: UUID?
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

        guard tripWorkspaceID == nil || kind == .expense else {
            throw TransactionFormError.tripRequiresExpense
        }

        guard budgetJarOverrideID == nil || tripWorkspaceID != nil else {
            throw TransactionFormError.jarOverrideRequiresTrip
        }

        return ValidatedValues(
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: accountID,
            categoryID: categoryID,
            tripWorkspaceID: tripWorkspaceID,
            budgetJarOverrideID: budgetJarOverrideID
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
            createdAt: createdAt,
            tripWorkspaceID: values.tripWorkspaceID,
            budgetJarOverrideID: values.budgetJarOverrideID
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
        transaction.tripWorkspaceID = values.tripWorkspaceID
        transaction.budgetJarOverrideID = values.budgetJarOverrideID
    }
}
