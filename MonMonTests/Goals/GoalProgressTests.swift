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

    @Test("Goal action status prioritizes the next decision")
    func actionStatusPrioritizesNextDecision() {
        let needsMore = GoalProgress.snapshot(
            targetAmount: 1_000,
            earmarkedAmount: 100,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 200,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )
        let onTrack = GoalProgress.snapshot(
            targetAmount: 1_000,
            earmarkedAmount: 100,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 300,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )
        let ready = GoalProgress.snapshot(
            targetAmount: 1_000,
            earmarkedAmount: 1_000,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 0,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(needsMore.actionStatus == .needsMonthly(100))
        #expect(onTrack.actionStatus == .onTrack)
        #expect(ready.actionStatus == .readyToUse)
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

@Suite("Goal contributions")
struct GoalContributionTests {
    @Test("Marking a contribution updates earmarked metadata and records history")
    func contributionUpdatesGoalAndHistory() throws {
        let goal = makeGoal(earmarked: 2_000)
        let contributionID = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_900_000_000)

        try GoalContributionStore.record(
            amount: 3_000,
            on: goal,
            id: contributionID,
            occurredAt: occurredAt
        )

        #expect(goal.earmarkedAmount == 5_000)
        #expect(
            GoalContributionStore.entries(for: goal) == [
                GoalContribution(id: contributionID, amount: 3_000, occurredAt: occurredAt)
            ]
        )
    }

    @Test("A contribution cannot exceed the goal remainder")
    func contributionCannotExceedRemainder() {
        let goal = makeGoal(earmarked: 9_000)

        #expect(throws: GoalContributionError.exceedsRemaining) {
            try GoalContributionStore.record(
                amount: 2_000,
                on: goal,
                id: UUID(),
                occurredAt: .now
            )
        }
        #expect(goal.earmarkedAmount == 9_000)
        #expect(GoalContributionStore.entries(for: goal).isEmpty)
    }

    private func makeGoal(earmarked: Decimal) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Macbook",
            targetAmount: 10_000,
            earmarkedAmount: earmarked,
            targetDate: Date(timeIntervalSince1970: 2_000_000_000),
            monthlyContribution: 1_000,
            fundingJarID: UUID(),
            symbolName: "laptopcomputer",
            colorName: "blue",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

@Suite("Goal archive and filters")
struct GoalArchiveTests {
    @Test("Only completed goals can be archived and restored")
    func archiveRequiresCompletion() throws {
        let incomplete = goal(name: "Camera", target: 10_000, earmarked: 5_000)
        let complete = goal(name: "Macbook", target: 10_000, earmarked: 10_000)
        let archivedAt = Date(timeIntervalSince1970: 1_950_000_000)

        #expect(throws: GoalArchiveError.goalIsIncomplete) {
            try GoalArchive.archive(incomplete, at: archivedAt)
        }

        try GoalArchive.archive(complete, at: archivedAt)
        #expect(complete.archivedAt == archivedAt)
        #expect(GoalCommitment.activeMonthlyContribution(for: complete) == 0)
        #expect(
            GoalActionStatus.resolve(
                progress: GoalProgress.snapshot(goal: complete, asOf: archivedAt),
                isArchived: true
            ) == .archived
        )

        GoalArchive.restore(complete)
        #expect(complete.archivedAt == nil)
    }

    @Test("Goal list snapshot separates active completed trips and archived")
    func listSnapshotSeparatesFilters() {
        let active = goal(name: "Camera", target: 10_000, earmarked: 5_000)
        let complete = goal(name: "Macbook", target: 10_000, earmarked: 10_000)
        let archived = goal(name: "Old goal", target: 5_000, earmarked: 5_000)
        archived.archivedAt = Date(timeIntervalSince1970: 1_950_000_000)
        let tripGoal = goal(name: "Japan", target: 20_000, earmarked: 20_000)
        let trip = TripWorkspace(
            id: UUID(),
            sourceGoalID: tripGoal.id,
            name: "Japan",
            budgetAmount: 20_000,
            fundingJarID: tripGoal.fundingJarID,
            symbolName: "airplane",
            colorName: "sky",
            status: .active,
            startedAt: Date(timeIntervalSince1970: 1_940_000_000),
            completedAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_940_000_000)
        )

        let snapshot = GoalListSnapshot.snapshot(
            goals: [active, complete, archived, tripGoal],
            workspaces: [trip]
        )

        #expect(snapshot.activeGoals.map(\.id) == [active.id])
        #expect(snapshot.completedGoals.map(\.id) == [complete.id])
        #expect(snapshot.archivedGoals.map(\.id) == [archived.id])
        #expect(snapshot.activeTrips.map(\.id) == [trip.id])
    }

    private func goal(
        name: String,
        target: Decimal,
        earmarked: Decimal
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: name,
            targetAmount: target,
            earmarkedAmount: earmarked,
            targetDate: Date(timeIntervalSince1970: 2_000_000_000),
            monthlyContribution: 1_000,
            fundingJarID: UUID(),
            symbolName: "target",
            colorName: "blue",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
