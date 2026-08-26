import Foundation

enum SavingsWithdrawalFormError: Error, Equatable {
    case invalidPrincipal
    case nonPositivePrincipal
    case exceedsRemainingPrincipal
    case invalidAmountReceived
    case negativeAmountReceived
    case missingAccount
    case beforeOpeningDate
    case futureDate
}

struct SavingsWithdrawalDraft: Equatable {
    var principalText: String
    var amountReceivedText: String
    var withdrawnAt: Date
    var destinationAccountID: UUID?
    var note: String

    init(
        principalText: String = "",
        amountReceivedText: String = "",
        withdrawnAt: Date,
        destinationAccountID: UUID? = nil,
        note: String = ""
    ) {
        self.principalText = principalText
        self.amountReceivedText = amountReceivedText
        self.withdrawnAt = withdrawnAt
        self.destinationAccountID = destinationAccountID
        self.note = note
    }

    init(withdrawal: SavingsWithdrawal) {
        self.init(
            principalText: VNDCurrency.formatPlain(withdrawal.principal),
            amountReceivedText: VNDCurrency.formatPlain(withdrawal.amountReceived),
            withdrawnAt: withdrawal.withdrawnAt,
            destinationAccountID: withdrawal.destinationAccountID,
            note: withdrawal.note
        )
    }

    struct ValidatedValues: Equatable {
        var principal: Decimal
        var amountReceived: Decimal
        var withdrawnAt: Date
        var destinationAccountID: UUID
        var note: String
    }

    func validate(
        remainingPrincipal: Decimal,
        openedAt: Date,
        asOf: Date
    ) throws -> ValidatedValues {
        guard let principal = VNDCurrency.parse(principalText) else {
            throw SavingsWithdrawalFormError.invalidPrincipal
        }
        guard principal > 0 else {
            throw SavingsWithdrawalFormError.nonPositivePrincipal
        }
        guard principal <= remainingPrincipal else {
            throw SavingsWithdrawalFormError.exceedsRemainingPrincipal
        }
        guard let amountReceived = VNDCurrency.parse(amountReceivedText) else {
            throw SavingsWithdrawalFormError.invalidAmountReceived
        }
        guard amountReceived >= 0 else {
            throw SavingsWithdrawalFormError.negativeAmountReceived
        }
        guard let destinationAccountID else {
            throw SavingsWithdrawalFormError.missingAccount
        }
        guard withdrawnAt >= openedAt else {
            throw SavingsWithdrawalFormError.beforeOpeningDate
        }
        guard withdrawnAt <= asOf else {
            throw SavingsWithdrawalFormError.futureDate
        }

        return ValidatedValues(
            principal: principal,
            amountReceived: amountReceived,
            withdrawnAt: withdrawnAt,
            destinationAccountID: destinationAccountID,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func makeWithdrawal(
        id: UUID,
        depositID: UUID,
        createdAt: Date,
        remainingPrincipal: Decimal,
        openedAt: Date,
        asOf: Date
    ) throws -> SavingsWithdrawal {
        let values = try validate(
            remainingPrincipal: remainingPrincipal,
            openedAt: openedAt,
            asOf: asOf
        )

        return SavingsWithdrawal(
            id: id,
            depositID: depositID,
            principal: values.principal,
            amountReceived: values.amountReceived,
            destinationAccountID: values.destinationAccountID,
            withdrawnAt: values.withdrawnAt,
            note: values.note,
            createdAt: createdAt
        )
    }

    func apply(
        to withdrawal: SavingsWithdrawal,
        remainingPrincipal: Decimal,
        openedAt: Date,
        asOf: Date
    ) throws {
        let values = try validate(
            remainingPrincipal: remainingPrincipal,
            openedAt: openedAt,
            asOf: asOf
        )

        withdrawal.principal = values.principal
        withdrawal.amountReceived = values.amountReceived
        withdrawal.destinationAccountID = values.destinationAccountID
        withdrawal.withdrawnAt = values.withdrawnAt
        withdrawal.note = values.note
    }
}
