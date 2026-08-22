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

    func makeAccount(id: UUID, createdAt: Date) throws -> CashAccount {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AccountFormError.emptyName
        }

        guard let openingBalance = VNDCurrency.parse(openingBalanceText) else {
            throw AccountFormError.invalidOpeningBalance
        }

        guard openingBalance >= 0 else {
            throw AccountFormError.negativeOpeningBalance
        }

        return CashAccount(
            id: id,
            name: trimmedName,
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }
}
