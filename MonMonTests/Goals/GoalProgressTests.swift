import Foundation
import Testing

@testable import MonMon

@Suite("Goal progress")
struct GoalProgressTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("Required monthly contribution uses every month through the target")
    func requiredMonthlyUsesMonthsThroughTarget() {
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 100,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 300
        )

        let snapshot = GoalProgress.snapshot(
            goal: goal,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(snapshot.remainingAmount == 900)
        #expect(snapshot.requiredMonthlyContribution == 300)
        #expect(snapshot.forecastCompletionDate == date(2027, 3, 31))
        #expect(snapshot.progress == 0.1)
        #expect(snapshot.monthlyContributionShortfall == 0)
        #expect(snapshot.isOnTrack)
    }

    @Test("Plan health reports the extra monthly contribution needed")
    func planHealthReportsMonthlyShortfall() {
        let snapshot = GoalProgress.snapshot(
            targetAmount: 1_000,
            earmarkedAmount: 100,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 200,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(snapshot.requiredMonthlyContribution == 300)
        #expect(snapshot.monthlyContributionShortfall == 100)
        #expect(!snapshot.isOnTrack)
        #expect(snapshot.forecastCompletionDate == date(2027, 5, 31))
    }

    @Test("Required monthly contribution rounds up to a whole dong")
    func requiredMonthlyRoundsUp() {
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 1,
            targetDate: date(2027, 2, 28),
            monthlyContribution: 0
        )

        let snapshot = GoalProgress.snapshot(
            goal: goal,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(snapshot.requiredMonthlyContribution == 500)
        #expect(snapshot.forecastCompletionDate == nil)
    }

    @Test("A completed goal has no remainder and completes now")
    func completedGoalCompletesNow() {
        let asOf = date(2027, 1, 15)
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 1_000,
            targetDate: date(2027, 12, 31),
            monthlyContribution: 100
        )

        let snapshot = GoalProgress.snapshot(goal: goal, asOf: asOf, calendar: calendar)

        #expect(snapshot.isComplete)
        #expect(snapshot.remainingAmount == 0)
        #expect(snapshot.requiredMonthlyContribution == 0)
        #expect(snapshot.forecastCompletionDate == asOf)
        #expect(snapshot.progress == 1)
    }

    private func makeGoal(
        targetAmount: Decimal,
        earmarkedAmount: Decimal,
        targetDate: Date,
        monthlyContribution: Decimal
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Home",
            targetAmount: targetAmount,
            earmarkedAmount: earmarkedAmount,
            targetDate: targetDate,
            monthlyContribution: monthlyContribution,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "house.fill",
            colorName: "blue",
            createdAt: date(2027, 1, 1)
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        guard
            let date = calendar.date(
                from: DateComponents(year: year, month: month, day: day))
        else {
            preconditionFailure("Invalid test date")
        }
        return date
    }
}

@Suite("Goal jar commitment")
struct GoalJarCommitmentTests {
    @Test("Every jar gets goal commitment and available capacity")
    func commitmentsAreGroupedByJar() {
        let savingsID = UUID()
        let playID = UUID()
        let goals = [
            goal(jarID: savingsID, target: 10_000, earmarked: 1_000, monthly: 600),
            goal(jarID: playID, target: 5_000, earmarked: 500, monthly: 200),
        ]

        let snapshots = GoalCommitment.snapshots(
            jarIDs: [savingsID, playID],
            goals: goals,
            plannedByJar: [savingsID: 1_000, playID: 500]
        )

        #expect(snapshots[savingsID]?.committedAmount == 600)
        #expect(snapshots[savingsID]?.availableAmount == 400)
        #expect(snapshots[playID]?.committedAmount == 200)
        #expect(snapshots[playID]?.availableAmount == 300)
    }

    @Test("Several active goals commit one jar plan exactly once")
    func activeGoalsAreAggregated() {
        let jarID = UUID()
        let goals = [
            goal(jarID: jarID, target: 10_000, earmarked: 1_000, monthly: 600),
            goal(jarID: jarID, target: 5_000, earmarked: 500, monthly: 500),
            goal(jarID: jarID, target: 2_000, earmarked: 2_000, monthly: 900),
            goal(jarID: UUID(), target: 8_000, earmarked: 0, monthly: 700),
        ]

        let snapshot = GoalCommitment.snapshot(
            jarID: jarID,
            goals: goals,
            plannedCapacity: 1_000
        )

        #expect(snapshot.goalCount == 2)
        #expect(snapshot.committedAmount == 1_100)
        #expect(snapshot.availableAmount == 0)
        #expect(snapshot.overcommittedAmount == 100)
        #expect(snapshot.isOvercommitted)
    }

    private func goal(
        jarID: UUID,
        target: Decimal,
        earmarked: Decimal,
        monthly: Decimal
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Goal",
            targetAmount: target,
            earmarkedAmount: earmarked,
            targetDate: Date(timeIntervalSince1970: 1_900_000_000),
            monthlyContribution: monthly,
            fundingJarID: jarID,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
