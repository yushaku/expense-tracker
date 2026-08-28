import Foundation

enum DebtPaymentFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case exceedsOutstanding
    case insufficientSourceBalance
}

struct DebtPaymentDraft: Equatable {
    var amountText: String
    var occurredAt: Date
    var accountID: UUID?
    var note: String

    init(
        amountText: String = "",
        occurredAt: Date,
        accountID: UUID? = nil,
        note: String = ""
    ) {
        self.amountText = amountText
        self.occurredAt = occurredAt
        self.accountID = accountID
        self.note = note
    }

    init(payment: DebtPayment) {
        self.init(
            amountText: VNDCurrency.formatPlain(payment.amount),
            occurredAt: payment.occurredAt,
            accountID: payment.accountID,
            note: payment.note
        )
    }

    /// Validated values ready to write to a model. `debtID` is absent on
    /// purpose: the editor is always opened from one debt, so it travels with
    /// `id` and `createdAt` rather than through the form.
    struct ValidatedValues: Equatable {
        var amount: Decimal
        var occurredAt: Date
        var accountID: UUID
        var note: String
    }

    /// Takes three scalars rather than the debt and its payments, so the draft
    /// depends on neither `Debt` nor `DebtSummary` and stays testable without a
    /// `ModelContext`.
    ///
    /// - Parameter direction: which way the parent debt points, which decides
    ///   whether this payment spends money or receives it.
    /// - Parameter outstanding: what is still owed. A payment may never take a
    ///   debt past settled: allowing it would flip a payable into a phantom
    ///   asset, and clamping it would drop cash without dropping what is owed,
    ///   so net worth would fall by the excess out of nowhere. Paying principal
    ///   plus interest is not the exception it looks like — interest is
    ///   projected, never owed here, and interest actually paid is an ordinary
    ///   expense. When editing, the caller adds this payment's own amount back.
    /// - Parameter availableSourceBalance: spendable balance of the account the
    ///   money leaves, or `nil` when no account is picked yet, the account may
    ///   go negative as a credit card may, or the money is arriving rather than
    ///   leaving. When editing, the caller removes this payment's own signed
    ///   amount first.
    func validate(
        direction: DebtDirection,
        outstanding: Decimal,
        availableSourceBalance: Decimal?
    ) throws -> ValidatedValues {
        guard let amount = VNDCurrency.parse(amountText) else {
            throw DebtPaymentFormError.invalidAmount
        }

        guard amount > 0 else {
            throw DebtPaymentFormError.nonPositiveAmount
        }

        guard let accountID else {
            throw DebtPaymentFormError.missingAccount
        }

        guard amount <= outstanding else {
            throw DebtPaymentFormError.exceedsOutstanding
        }

        // Only a repayment spends money. Being repaid on something lent is an
        // inflow, so there is nothing to overdraw.
        if direction == .borrowed,
            let availableSourceBalance,
            amount > availableSourceBalance
        {
            throw DebtPaymentFormError.insufficientSourceBalance
        }

        return ValidatedValues(
            amount: amount,
            occurredAt: occurredAt,
            accountID: accountID,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func makePayment(
        id: UUID,
        debtID: UUID,
        createdAt: Date,
        direction: DebtDirection,
        outstanding: Decimal,
        availableSourceBalance: Decimal?
    ) throws -> DebtPayment {
        let values = try validate(
            direction: direction,
            outstanding: outstanding,
            availableSourceBalance: availableSourceBalance
        )

        return DebtPayment(
            id: id,
            debtID: debtID,
            amount: values.amount,
            occurredAt: values.occurredAt,
            accountID: values.accountID,
            note: values.note,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    func apply(
        to payment: DebtPayment,
        direction: DebtDirection,
        outstanding: Decimal,
        availableSourceBalance: Decimal?
    ) throws {
        let values = try validate(
            direction: direction,
            outstanding: outstanding,
            availableSourceBalance: availableSourceBalance
        )

        payment.amount = values.amount
        payment.occurredAt = values.occurredAt
        payment.accountID = values.accountID
        payment.note = values.note
    }
}
