import Foundation

enum AccountFormError: Error, Equatable {
    case emptyName
    case invalidOpeningBalance
    case negativeOpeningBalance
}

struct AccountDraft: Equatable {
    var name: String
    var kind: CashAccountKind
    var openingBalanceText: String

    init(
        name: String = "",
        kind: CashAccountKind = .cash,
        openingBalanceText: String = ""
    ) {
        self.name = name
        self.kind = kind
        self.openingBalanceText = openingBalanceText
    }

    /// Seeds the editor with an existing account. The balance is formatted with
    /// the same grouping the parser accepts back, so an untouched field
    /// round-trips to the value it started from.
    init(account: CashAccount) {
        self.init(
            name: account.name,
            kind: account.kind,
            openingBalanceText: VNDCurrency.formatPlain(account.openingBalance)
        )
    }

    private struct ValidatedValues {
        let name: String
        let openingBalance: Decimal
    }

    private func validate() throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AccountFormError.emptyName
        }

        guard let openingBalance = VNDCurrency.parse(openingBalanceText) else {
            throw AccountFormError.invalidOpeningBalance
        }

        guard openingBalance >= 0 || kind.allowsNegativeBalance else {
            throw AccountFormError.negativeOpeningBalance
        }

        return ValidatedValues(name: trimmedName, openingBalance: openingBalance)
    }

    func makeAccount(id: UUID, createdAt: Date) throws -> CashAccount {
        let values = try validate()

        return CashAccount(
            id: id,
            name: values.name,
            kind: kind,
            openingBalance: values.openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    /// Writes the validated draft onto an existing account. Identity fields
    /// (`id`, `createdAt`, `currencyCode`) are left untouched.
    func apply(to account: CashAccount) throws {
        let values = try validate()

        account.name = values.name
        account.kind = kind
        account.openingBalance = values.openingBalance
    }
}
