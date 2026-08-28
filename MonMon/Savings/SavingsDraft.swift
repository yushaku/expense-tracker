import Foundation

enum SavingsFormError: Error, Equatable {
    case emptyName
    case invalidPrincipal
    case nonPositivePrincipal
    case invalidRate
    case rateOutOfRange
    case invalidTerm
    case termOutOfRange
    case insufficientSourceBalance
}

struct SavingsDraft: Equatable {
    static let rateRange: ClosedRange<Decimal> = 0...100
    static let termRange: ClosedRange<Int> = 1...120

    var name: String
    @VNDInput var principalText: String
    var rateText: String
    var termMonthsText: String
    var openedAt: Date
    var sourceAccountID: UUID?

    init(
        name: String = "",
        principalText: String = "",
        rateText: String = "",
        termMonthsText: String = "",
        openedAt: Date,
        sourceAccountID: UUID? = nil
    ) {
        self.name = name
        self.principalText = principalText
        self.rateText = rateText
        self.termMonthsText = termMonthsText
        self.openedAt = openedAt
        self.sourceAccountID = sourceAccountID
    }

    init(deposit: SavingsDeposit) {
        self.init(
            name: deposit.name,
            principalText: VNDCurrency.formatPlain(deposit.principal),
            rateText: PercentInput.format(deposit.annualInterestRate),
            termMonthsText: String(deposit.termMonths),
            openedAt: deposit.openedAt,
            sourceAccountID: deposit.sourceAccountID
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var name: String
        var principal: Decimal
        var annualInterestRate: Decimal
        var termMonths: Int
        var openedAt: Date
    }

    /// - Parameter availableSourceBalance: spendable balance of the selected
    ///   source account, or `nil` when the deposit is not funded from one.
    ///   When editing, the caller adds this deposit's current principal back so
    ///   re-saving an unchanged amount never reports an overdraft.
    func validate(availableSourceBalance: Decimal?) throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SavingsFormError.emptyName
        }

        guard let principal = VNDCurrency.parse(principalText) else {
            throw SavingsFormError.invalidPrincipal
        }

        guard principal > 0 else {
            throw SavingsFormError.nonPositivePrincipal
        }

        guard let rate = PercentInput.parse(rateText) else {
            throw SavingsFormError.invalidRate
        }

        guard Self.rateRange.contains(rate) else {
            throw SavingsFormError.rateOutOfRange
        }

        let trimmedTerm = termMonthsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let termMonths = Int(trimmedTerm) else {
            throw SavingsFormError.invalidTerm
        }

        guard Self.termRange.contains(termMonths) else {
            throw SavingsFormError.termOutOfRange
        }

        if let availableSourceBalance, principal > availableSourceBalance {
            throw SavingsFormError.insufficientSourceBalance
        }

        return ValidatedValues(
            name: trimmedName,
            principal: principal,
            annualInterestRate: rate,
            termMonths: termMonths,
            openedAt: openedAt
        )
    }

    func makeDeposit(
        id: UUID,
        createdAt: Date,
        availableSourceBalance: Decimal?
    ) throws -> SavingsDeposit {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        return SavingsDeposit(
            id: id,
            name: values.name,
            principal: values.principal,
            annualInterestRate: values.annualInterestRate,
            termMonths: values.termMonths,
            openedAt: values.openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )
    }

    func apply(
        to deposit: SavingsDeposit,
        availableSourceBalance: Decimal?
    ) throws {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        deposit.name = values.name
        deposit.principal = values.principal
        deposit.annualInterestRate = values.annualInterestRate
        deposit.termMonths = values.termMonths
        deposit.openedAt = values.openedAt
        deposit.sourceAccountID = sourceAccountID
    }
}
