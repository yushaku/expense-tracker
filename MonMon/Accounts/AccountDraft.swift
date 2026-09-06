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
    /// Empty until a colour is picked, and left empty when it is not: an
    /// account nobody has coloured keeps following its kind.
    var colorName: String

    /// A new account starts at zero rather than blank: most accounts are opened
    /// with nothing in them yet, and an owner who does have a balance types over
    /// a nought as readily as into an empty field. It also means the form can be
    /// saved the moment it has a name.
    init(
        name: String = "",
        kind: CashAccountKind = .normal,
        openingBalanceText: String = "0",
        creditLimitText: String = "",
        colorName: String = ""
    ) {
        self.name = name
        self.kind = kind
        self.openingBalanceText = openingBalanceText
        self.creditLimitText = creditLimitText
        self.colorName = colorName
    }

    /// Which swatch the picker shows as chosen — the colour the account is
    /// actually drawn in, picked or inherited.
    var effectiveColorName: String {
        colorName.isEmpty ? kind.defaultColorName : colorName
    }

    /// Seeds the editor with an existing account. The balance is formatted with
    /// the same grouping the parser accepts back, so an untouched field
    /// round-trips to the value it started from.
    init(account: CashAccount) {
        self.init(
            name: account.name,
            kind: account.kind,
            openingBalanceText: VNDCurrency.formatPlain(account.openingBalance),
            creditLimitText: VNDCurrency.formatPlain(account.creditLimit),
            colorName: account.colorName
        )
    }

    private struct ValidatedValues {
        let name: String
        let openingBalance: Decimal
        let creditLimit: Decimal
        let colorName: String
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
            creditLimit: creditLimit,
            // An unknown name would draw as the palette's fallback while
            // claiming to be something else, so it is dropped back to
            // inheriting instead.
            colorName: colorName.isEmpty ? "" : CategoryPalette.colorName(colorName)
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
            colorName: values.colorName,
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
        account.colorName = values.colorName
    }
}
