import Foundation

enum AccountFormError: Error, Equatable {
    case emptyName
    case invalidOpeningBalance
    case negativeOpeningBalance
    case invalidCreditLimit
    case negativeCreditLimit
}

struct AccountDraft: Equatable {
    var name: String
    var kind: CashAccountKind
    var openingBalanceText: String
    var creditLimitText: String

    /// A new account starts at zero rather than blank: most accounts are opened
    /// with nothing in them yet, and an owner who does have a balance types over
    /// a nought as readily as into an empty field. It also means the form can be
    /// saved the moment it has a name.
    init(
        name: String = "",
        kind: CashAccountKind = .normal,
        openingBalanceText: String = "0",
        creditLimitText: String = ""
    ) {
        self.name = name
        self.kind = kind
        self.openingBalanceText = openingBalanceText
        self.creditLimitText = creditLimitText
    }

    /// Seeds the editor with an existing account. The balance is formatted with
    /// the same grouping the parser accepts back, so an untouched field
    /// round-trips to the value it started from.
    init(account: CashAccount) {
        self.init(
            name: account.name,
            kind: account.kind,
            openingBalanceText: VNDCurrency.formatPlain(account.openingBalance),
            creditLimitText: VNDCurrency.formatPlain(account.creditLimit)
        )
    }

    private struct ValidatedValues {
        let name: String
        let openingBalance: Decimal
        let creditLimit: Decimal
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

        let creditLimit: Decimal
        if kind == .credit {
            guard let parsedLimit = VNDCurrency.parse(creditLimitText) else {
                throw AccountFormError.invalidCreditLimit
            }
            guard parsedLimit >= 0 else {
                throw AccountFormError.negativeCreditLimit
            }
            creditLimit = parsedLimit
        } else {
            creditLimit = .zero
        }

        return ValidatedValues(
            name: trimmedName,
            openingBalance: openingBalance,
            creditLimit: creditLimit
        )
    }

    func makeAccount(id: UUID, createdAt: Date) throws -> CashAccount {
        let values = try validate()

        return CashAccount(
            id: id,
            name: values.name,
            kind: kind,
            openingBalance: values.openingBalance,
            creditLimit: values.creditLimit,
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
        account.creditLimit = values.creditLimit
    }
}
