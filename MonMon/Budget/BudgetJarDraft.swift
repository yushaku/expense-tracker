import Foundation

enum BudgetJarFormError: Error, Equatable {
    case emptyName
    case duplicateName
    case invalidPercent
    case negativePercent
    case allocationExceeds100
}

struct BudgetJarDraft: Equatable {
    var name: String
    var allocationText: String
    var symbolName: String
    var colorName: String

    init(
        name: String = "",
        allocationText: String = "",
        symbolName: String = CategoryPalette.defaultSymbolName,
        colorName: String = CategoryPalette.defaultColorName
    ) {
        self.name = name
        self.allocationText = allocationText
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
    }

    init(jar: BudgetJar) {
        self.init(
            name: jar.name,
            allocationText: PercentInput.format(jar.allocationPercent),
            symbolName: jar.symbolName,
            colorName: jar.colorName
        )
    }

    struct ValidatedValues: Equatable {
        var name: String
        var allocationPercent: Decimal
        var symbolName: String
        var colorName: String
    }

    func validate(existing: [BudgetJar], editedID: UUID?) throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw BudgetJarFormError.emptyName
        }

        guard
            !existing.contains(where: {
                $0.id != editedID
                    && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
            })
        else {
            throw BudgetJarFormError.duplicateName
        }

        guard let allocationPercent = PercentInput.parse(allocationText) else {
            throw BudgetJarFormError.invalidPercent
        }
        guard allocationPercent >= 0 else {
            throw BudgetJarFormError.negativePercent
        }

        let existingTotal =
            existing
            .filter { $0.id != editedID }
            .reduce(Decimal.zero) { $0 + $1.allocationPercent }
        guard existingTotal + allocationPercent <= 100 else {
            throw BudgetJarFormError.allocationExceeds100
        }

        return ValidatedValues(
            name: trimmedName,
            allocationPercent: allocationPercent,
            symbolName: CategoryPalette.symbolName(symbolName),
            colorName: CategoryPalette.colorName(colorName)
        )
    }

    func makeJar(
        id: UUID,
        createdAt: Date,
        existing: [BudgetJar]
    ) throws -> BudgetJar {
        let values = try validate(existing: existing, editedID: nil)
        return BudgetJar(
            id: id,
            name: values.name,
            allocationPercent: values.allocationPercent,
            role: .custom,
            symbolName: values.symbolName,
            colorName: values.colorName,
            createdAt: createdAt
        )
    }

    func apply(to jar: BudgetJar, existing: [BudgetJar]) throws {
        let values = try validate(existing: existing, editedID: jar.id)
        jar.name = values.name
        jar.allocationPercent = values.allocationPercent
        jar.symbolName = values.symbolName
        jar.colorName = values.colorName
    }
}

struct BudgetJarAllocationImpact: Equatable {
    let currentMonthlyAmount: Decimal
    let proposedMonthlyAmount: Decimal
    let goalCommitment: GoalCommitmentSnapshot?
    let affectedGoalNames: [String]

    var monthlyChange: Decimal {
        proposedMonthlyAmount - currentMonthlyAmount
    }
}

enum BudgetJarImpact {
    static func snapshot(
        jarID: UUID?,
        currentPercent: Decimal,
        proposedPercent: Decimal,
        plannedIncome: Decimal,
        goals: [FinancialGoal]
    ) -> BudgetJarAllocationImpact {
        let currentMonthlyAmount = BudgetSummary.allocation(
            of: plannedIncome,
            percent: currentPercent
        )
        let proposedMonthlyAmount = BudgetSummary.allocation(
            of: plannedIncome,
            percent: proposedPercent
        )

        guard let jarID else {
            return BudgetJarAllocationImpact(
                currentMonthlyAmount: currentMonthlyAmount,
                proposedMonthlyAmount: proposedMonthlyAmount,
                goalCommitment: nil,
                affectedGoalNames: []
            )
        }

        let commitment = GoalCommitment.snapshot(
            jarID: jarID,
            goals: goals,
            plannedCapacity: proposedMonthlyAmount
        )
        let affectedGoalNames =
            commitment.isOvercommitted
            ? goals
                .filter {
                    $0.fundingJarID == jarID
                        && GoalCommitment.activeMonthlyContribution(for: $0) > 0
                }
                .sorted { $0.createdAt < $1.createdAt }
                .map(\.name)
            : []

        return BudgetJarAllocationImpact(
            currentMonthlyAmount: currentMonthlyAmount,
            proposedMonthlyAmount: proposedMonthlyAmount,
            goalCommitment: commitment,
            affectedGoalNames: affectedGoalNames
        )
    }
}
