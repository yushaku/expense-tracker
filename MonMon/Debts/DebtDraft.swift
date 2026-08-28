import Foundation

enum DebtFormError: Error, Equatable {
    case emptyCounterparty
    case invalidPrincipal
    case nonPositivePrincipal
    case invalidRate
    case rateOutOfRange
    case dueDateBeforeOpening
    case insufficientSourceBalance
    case principalBelowPaid
}

struct DebtDraft: Equatable {
    static let rateRange: ClosedRange<Decimal> = 0...100

    var counterparty: String
    var direction: DebtDirection
    var principalText: String
    /// Blank means zero. An interest-free loan from a relative is the common
    /// case and should not require a typed nought — a deliberate divergence
    /// from `SavingsDraft`, where a term deposit paying nothing is nonsense.
    var rateText: String
    var openedAt: Date
    /// Held apart from `dueDate` because `DateField` binds a non-optional
    /// `Date`, so the toggle owns whether the date is used at all.
    var hasDueDate: Bool
    var dueDate: Date
    var accountID: UUID?
    var note: String

    init(
        counterparty: String = "",
        direction: DebtDirection = .borrowed,
        principalText: String = "",
        rateText: String = "",
        openedAt: Date,
        hasDueDate: Bool = false,
        dueDate: Date? = nil,
        accountID: UUID? = nil,
        note: String = ""
    ) {
        self.counterparty = counterparty
        self.direction = direction
        self.principalText = principalText
        self.rateText = rateText
        self.openedAt = openedAt
        self.hasDueDate = hasDueDate
        self.dueDate = dueDate ?? openedAt
        self.accountID = accountID
        self.note = note
    }

    init(debt: Debt) {
        self.init(
            counterparty: debt.counterparty,
            direction: debt.direction,
            principalText: VNDCurrency.formatPlain(debt.principal),
            rateText: debt.annualInterestRate > 0
                ? PercentInput.format(debt.annualInterestRate) : "",
            openedAt: debt.openedAt,
            hasDueDate: debt.dueDate != nil,
            dueDate: debt.dueDate,
            accountID: debt.accountID,
            note: debt.note
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var counterparty: String
        var direction: DebtDirection
        var principal: Decimal
        var annualInterestRate: Decimal
        var openedAt: Date
        var dueDate: Date?
        var accountID: UUID?
        var note: String
    }

    /// The principal is always validated positive; `direction` alone carries
    /// direction. The account stays optional: a debt taken before this app
    /// existed is already inside an `openingBalance`, and naming an account
    /// would credit the same money twice.
    ///
    /// - Parameter availableSourceBalance: spendable balance of the account the
    ///   money leaves, or `nil` when no account is picked yet or the account is
    ///   allowed to go negative, as a credit card is. When editing, the caller
    ///   removes this debt's own **signed** principal first — signed, because a
    ///   debt's contribution flips with its direction, so adding the amount back
    ///   unconditionally would over-credit by twice the principal when the owner
    ///   flips a debt from borrowed to lent.
    /// - Parameter alreadyPaid: what has been paid against this debt, so the
    ///   principal cannot be edited below it and drive the outstanding balance
    ///   negative. Zero when adding.
    func validate(
        availableSourceBalance: Decimal?,
        alreadyPaid: Decimal = .zero
    ) throws -> ValidatedValues {
        let trimmedCounterparty = counterparty.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCounterparty.isEmpty else {
            throw DebtFormError.emptyCounterparty
        }

        guard let principal = VNDCurrency.parse(principalText) else {
            throw DebtFormError.invalidPrincipal
        }

        guard principal > 0 else {
            throw DebtFormError.nonPositivePrincipal
        }

        let rate = try parsedRate()

        guard Self.rateRange.contains(rate) else {
            throw DebtFormError.rateOutOfRange
        }

        let resolvedDueDate = hasDueDate ? dueDate : nil

        if let resolvedDueDate,
            DebtInterest.dayCount(from: openedAt, to: resolvedDueDate) < 0
        {
            // A backwards span projects no interest, and silently showing
            // nothing is worse than saying so.
            throw DebtFormError.dueDateBeforeOpening
        }

        // Borrowing puts money into the account, so there is nothing to
        // overdraw. Capping it would refuse to borrow a large sum into a small
        // wallet, which is the single most common thing this module is for. The
        // guard is skipped here rather than merely left uncapped by the caller,
        // so the rule is testable on its own.
        if direction == .lent,
            let availableSourceBalance,
            principal > availableSourceBalance
        {
            throw DebtFormError.insufficientSourceBalance
        }

        guard principal >= alreadyPaid else {
            throw DebtFormError.principalBelowPaid
        }

        return ValidatedValues(
            counterparty: trimmedCounterparty,
            direction: direction,
            principal: principal,
            annualInterestRate: rate,
            openedAt: openedAt,
            dueDate: resolvedDueDate,
            accountID: accountID,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// A blank field means no interest. `PercentInput.parse` cannot say so on
    /// its own — it returns `nil` for an empty string as well as for junk — so
    /// the blank case is answered before asking it.
    private func parsedRate() throws -> Decimal {
        guard !rateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .zero
        }

        guard let rate = PercentInput.parse(rateText) else {
            throw DebtFormError.invalidRate
        }

        return rate
    }

    func makeDebt(
        id: UUID,
        createdAt: Date,
        availableSourceBalance: Decimal?
    ) throws -> Debt {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        return Debt(
            id: id,
            counterparty: values.counterparty,
            direction: values.direction,
            principal: values.principal,
            annualInterestRate: values.annualInterestRate,
            openedAt: values.openedAt,
            dueDate: values.dueDate,
            accountID: values.accountID,
            note: values.note,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    func apply(
        to debt: Debt,
        availableSourceBalance: Decimal?,
        alreadyPaid: Decimal
    ) throws {
        let values = try validate(
            availableSourceBalance: availableSourceBalance,
            alreadyPaid: alreadyPaid
        )

        debt.counterparty = values.counterparty
        debt.direction = values.direction
        debt.principal = values.principal
        debt.annualInterestRate = values.annualInterestRate
        debt.openedAt = values.openedAt
        debt.dueDate = values.dueDate
        debt.accountID = values.accountID
        debt.note = values.note
    }
}
