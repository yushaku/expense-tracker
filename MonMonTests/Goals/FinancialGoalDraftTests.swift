import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Financial goal draft")
struct FinancialGoalDraftTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let asOf = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A valid draft trims its name and creates a goal")
    func validDraftCreatesGoal() throws {
        let savings = jar(name: "Savings", percent: 10)
        let draft = FinancialGoalDraft(
            name: "  First home  ",
            kind: .home,
            targetAmountText: "1000000000",
            earmarkedAmountText: "100000000",
            targetDate: futureDate(months: 24),
            monthlyContributionText: "5000000",
            fundingJarID: savings.id
        )

        let goal = try draft.makeGoal(
            id: UUID(),
            createdAt: asOf,
            jars: [savings],
            goals: [],
            plannedByJar: [savings.id: 10_000_000],
            asOf: asOf,
            calendar: calendar
        )

        #expect(goal.name == "First home")
        #expect(goal.targetAmount == 1_000_000_000)
        #expect(goal.earmarkedAmount == 100_000_000)
        #expect(goal.monthlyContribution == 5_000_000)
        #expect(goal.fundingJarID == savings.id)
    }

    @Test("Amounts, date, and funding jar are validated")
    func invalidFieldsAreRejected() {
        let savings = jar(name: "Savings", percent: 10)

        #expect(throws: FinancialGoalFormError.emptyName) {
            _ = try draft(name: " ", jarID: savings.id).validated(
                jars: [savings], goals: [], plannedByJar: [:], editedID: nil,
                asOf: asOf, calendar: calendar)
        }
        #expect(throws: FinancialGoalFormError.nonPositiveTargetAmount) {
            var value = draft(jarID: savings.id)
            value.targetAmountText = "0"
            _ = try value.validated(
                jars: [savings], goals: [], plannedByJar: [:], editedID: nil,
                asOf: asOf, calendar: calendar)
        }
        #expect(throws: FinancialGoalFormError.earmarkedExceedsTarget) {
            var value = draft(jarID: savings.id)
            value.earmarkedAmountText = "2000"
            _ = try value.validated(
                jars: [savings], goals: [], plannedByJar: [:], editedID: nil,
                asOf: asOf, calendar: calendar)
        }
        #expect(throws: FinancialGoalFormError.targetDateInPast) {
            var value = draft(jarID: savings.id)
            value.targetDate = calendar.date(byAdding: .day, value: -1, to: asOf)!
            _ = try value.validated(
                jars: [savings], goals: [], plannedByJar: [:], editedID: nil,
                asOf: asOf, calendar: calendar)
        }
        #expect(throws: FinancialGoalFormError.missingFundingJar) {
            _ = try draft(jarID: UUID()).validated(
                jars: [savings], goals: [], plannedByJar: [:], editedID: nil,
                asOf: asOf, calendar: calendar)
        }
    }

    @Test("Several goals cannot double-commit one jar's monthly plan")
    func sharedJarCannotBeOvercommitted() {
        let savings = jar(name: "Savings", percent: 10)
        let existing = goal(jarID: savings.id, monthlyContribution: 600)
        var value = draft(jarID: savings.id)
        value.monthlyContributionText = "500"

        #expect(throws: FinancialGoalFormError.monthlyCommitmentExceedsJar) {
            _ = try value.validated(
                jars: [savings],
                goals: [existing],
                plannedByJar: [savings.id: 1_000],
                editedID: nil,
                asOf: asOf,
                calendar: calendar
            )
        }
    }

    @Test("Editing excludes the goal's previous monthly commitment")
    func editingExcludesPreviousCommitment() throws {
        let savings = jar(name: "Savings", percent: 10)
        let existing = goal(jarID: savings.id, monthlyContribution: 600)
        var value = draft(jarID: savings.id)
        value.monthlyContributionText = "700"

        let validated = try value.validated(
            jars: [savings],
            goals: [existing],
            plannedByJar: [savings.id: 1_000],
            editedID: existing.id,
            asOf: asOf,
            calendar: calendar
        )

        #expect(validated.monthlyContribution == 700)
    }

    private func draft(name: String = "Home", jarID: UUID?) -> FinancialGoalDraft {
        FinancialGoalDraft(
            name: name,
            kind: .home,
            targetAmountText: "1000",
            earmarkedAmountText: "100",
            targetDate: futureDate(months: 12),
            monthlyContributionText: "100",
            fundingJarID: jarID
        )
    }

    private func jar(name: String, percent: Decimal) -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: name,
            allocationPercent: percent,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: asOf
        )
    }

    private func goal(jarID: UUID, monthlyContribution: Decimal) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Existing",
            kind: .custom,
            targetAmount: 10_000,
            earmarkedAmount: 0,
            targetDate: futureDate(months: 12),
            monthlyContribution: monthlyContribution,
            fundingJarID: jarID,
            symbolName: "target",
            colorName: "green",
            createdAt: asOf
        )
    }

    private func futureDate(months: Int) -> Date {
        guard let date = calendar.date(byAdding: .month, value: months, to: asOf) else {
            preconditionFailure("Invalid test date")
        }
        return date
    }
}

@MainActor
@Suite("Financial goal persistence")
struct FinancialGoalPersistenceTests {
    @Test("A goal persists through the shared MonMon schema")
    func goalPersists() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let goal = FinancialGoal(
            id: UUID(),
            name: "Trip",
            kind: .trip,
            targetAmount: 30_000_000,
            earmarkedAmount: 5_000_000,
            targetDate: Date(timeIntervalSince1970: 1_900_000_000),
            monthlyContribution: 2_000_000,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        container.mainContext.insert(goal)
        try container.mainContext.save()

        let storedGoals = try container.mainContext.fetch(FetchDescriptor<FinancialGoal>())
        #expect(storedGoals.count == 1)
        let stored = try #require(storedGoals.first)
        #expect(stored.id == goal.id)
        #expect(stored.kind == FinancialGoalKind.trip)
        #expect(stored.fundingJarID == BudgetJarSeed.savingsID)
        #expect(stored.monthlyContribution == 2_000_000)
    }
}
