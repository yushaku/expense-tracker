import Foundation

enum FinancialGoalFormError: Error, Equatable {
    case emptyName
    case invalidTargetAmount
    case nonPositiveTargetAmount
    case invalidEarmarkedAmount
    case negativeEarmarkedAmount
    case earmarkedExceedsTarget
    case invalidMonthlyContribution
    case negativeMonthlyContribution
    case targetDateInPast
    case missingFundingJar
    case monthlyCommitmentExceedsJar
}

struct FinancialGoalDraft: Equatable {
    var name: String
    var kind: FinancialGoalKind
    var targetAmountText: String
    var earmarkedAmountText: String
    var targetDate: Date
    var monthlyContributionText: String
    var fundingJarID: UUID?
    var symbolName: String
    var colorName: String

    init(
        name: String = "",
        kind: FinancialGoalKind = .custom,
        targetAmountText: String = "",
        earmarkedAmountText: String = "0",
        targetDate: Date,
        monthlyContributionText: String = "0",
        fundingJarID: UUID? = nil,
        symbolName: String? = nil,
        colorName: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.targetAmountText = targetAmountText
        self.earmarkedAmountText = earmarkedAmountText
        self.targetDate = targetDate
        self.monthlyContributionText = monthlyContributionText
        self.fundingJarID = fundingJarID
        self.symbolName = CategoryPalette.symbolName(symbolName ?? kind.symbolName)
        self.colorName = CategoryPalette.colorName(colorName ?? kind.colorName)
    }

    init(goal: FinancialGoal) {
        self.init(
            name: goal.name,
            kind: goal.kind,
            targetAmountText: VNDCurrency.formatPlain(goal.targetAmount),
            earmarkedAmountText: VNDCurrency.formatPlain(goal.earmarkedAmount),
            targetDate: goal.targetDate,
            monthlyContributionText: VNDCurrency.formatPlain(goal.monthlyContribution),
            fundingJarID: goal.fundingJarID,
            symbolName: goal.symbolName,
            colorName: goal.colorName
        )
    }

    struct ValidatedValues: Equatable {
        var name: String
        var kind: FinancialGoalKind
        var targetAmount: Decimal
        var earmarkedAmount: Decimal
        var targetDate: Date
        var monthlyContribution: Decimal
        var fundingJarID: UUID
        var symbolName: String
        var colorName: String
    }

    func validated(
        jars: [BudgetJar],
        goals: [FinancialGoal],
        plannedByJar: [UUID: Decimal],
        editedID: UUID?,
        asOf: Date,
        calendar: Calendar = .current
    ) throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FinancialGoalFormError.emptyName
        }

        guard let targetAmount = VNDCurrency.parse(targetAmountText) else {
            throw FinancialGoalFormError.invalidTargetAmount
        }
        guard targetAmount > 0 else {
            throw FinancialGoalFormError.nonPositiveTargetAmount
        }

        guard let earmarkedAmount = VNDCurrency.parse(earmarkedAmountText) else {
            throw FinancialGoalFormError.invalidEarmarkedAmount
        }
        guard earmarkedAmount >= 0 else {
            throw FinancialGoalFormError.negativeEarmarkedAmount
        }
        guard earmarkedAmount <= targetAmount else {
            throw FinancialGoalFormError.earmarkedExceedsTarget
        }

        guard let monthlyContribution = VNDCurrency.parse(monthlyContributionText) else {
            throw FinancialGoalFormError.invalidMonthlyContribution
        }
        guard monthlyContribution >= 0 else {
            throw FinancialGoalFormError.negativeMonthlyContribution
        }

        guard !calendar.startOfDay(for: targetDate).isBefore(calendar.startOfDay(for: asOf))
        else {
            throw FinancialGoalFormError.targetDateInPast
        }

        let validJarIDs = Set(jars.map(\.id))
        guard let fundingJarID, validJarIDs.contains(fundingJarID) else {
            throw FinancialGoalFormError.missingFundingJar
        }

        let otherCommitment =
            goals
            .filter { $0.id != editedID && $0.fundingJarID == fundingJarID }
            .reduce(Decimal.zero) {
                $0 + GoalCommitment.activeMonthlyContribution(for: $1)
            }
        let candidateCommitment = GoalCommitment.activeMonthlyContribution(
            targetAmount: targetAmount,
            earmarkedAmount: earmarkedAmount,
            monthlyContribution: monthlyContribution
        )
        let capacity = plannedByJar[fundingJarID, default: .zero]
        let totalAfterSave = otherCommitment + candidateCommitment
        let previousContribution =
            goals.first { $0.id == editedID && $0.fundingJarID == fundingJarID }
            .map(GoalCommitment.activeMonthlyContribution(for:)) ?? .zero
        let totalBeforeSave = otherCommitment + previousContribution
        guard totalAfterSave <= capacity || totalAfterSave <= totalBeforeSave else {
            throw FinancialGoalFormError.monthlyCommitmentExceedsJar
        }

        return ValidatedValues(
            name: trimmedName,
            kind: kind,
            targetAmount: targetAmount,
            earmarkedAmount: earmarkedAmount,
            targetDate: targetDate,
            monthlyContribution: monthlyContribution,
            fundingJarID: fundingJarID,
            symbolName: CategoryPalette.symbolName(symbolName),
            colorName: CategoryPalette.colorName(colorName)
        )
    }

    func makeGoal(
        id: UUID,
        createdAt: Date,
        jars: [BudgetJar],
        goals: [FinancialGoal],
        plannedByJar: [UUID: Decimal],
        asOf: Date,
        calendar: Calendar = .current
    ) throws -> FinancialGoal {
        let values = try validated(
            jars: jars,
            goals: goals,
            plannedByJar: plannedByJar,
            editedID: nil,
            asOf: asOf,
            calendar: calendar
        )
        return FinancialGoal(
            id: id,
            name: values.name,
            kind: values.kind,
            targetAmount: values.targetAmount,
            earmarkedAmount: values.earmarkedAmount,
            targetDate: values.targetDate,
            monthlyContribution: values.monthlyContribution,
            fundingJarID: values.fundingJarID,
            symbolName: values.symbolName,
            colorName: values.colorName,
            createdAt: createdAt
        )
    }

    func apply(
        to goal: FinancialGoal,
        jars: [BudgetJar],
        goals: [FinancialGoal],
        plannedByJar: [UUID: Decimal],
        asOf: Date,
        calendar: Calendar = .current
    ) throws {
        let values = try validated(
            jars: jars,
            goals: goals,
            plannedByJar: plannedByJar,
            editedID: goal.id,
            asOf: asOf,
            calendar: calendar
        )
        goal.name = values.name
        goal.kind = values.kind
        goal.targetAmount = values.targetAmount
        goal.earmarkedAmount = values.earmarkedAmount
        goal.targetDate = values.targetDate
        goal.monthlyContribution = values.monthlyContribution
        goal.fundingJarID = values.fundingJarID
        goal.symbolName = values.symbolName
        goal.colorName = values.colorName
    }
}

private extension Date {
    func isBefore(_ other: Date) -> Bool {
        self < other
    }
}
