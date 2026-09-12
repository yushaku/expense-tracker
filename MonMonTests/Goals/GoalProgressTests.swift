import Foundation
import SwiftData
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
            capacityByJar: [savingsID: 1_000, playID: 500]
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

@Suite("Savings goal widget")
@MainActor
struct SavingsGoalWidgetTests {
    private func snapshot(amount: Decimal, target: Decimal = 50_000_000) -> GoalWidgetSnapshot {
        GoalWidgetSnapshot(
            id: UUID(), name: "Japan", targetAmount: target,
            earmarkedAmount: amount, symbolName: "airplane", colorName: "mauve", isArchived: false)
    }

    @Test("Milestones advance at exact boundaries and use earmarked money")
    func milestones() {
        let goal = snapshot(amount: 30_000_000)
        #expect(goal.progress == 0.6)
        #expect(goal.nextMilestonePercent == 75)
        #expect(goal.amountToNextMilestone == 7_500_000)
        #expect(goal.remainingAmount == 20_000_000)
        #expect(snapshot(amount: 0).nextMilestonePercent == 25)
        #expect(snapshot(amount: 12_500_000).nextMilestonePercent == 50)
        #expect(snapshot(amount: 25_000_000).nextMilestonePercent == 75)
        #expect(snapshot(amount: 37_500_000).nextMilestonePercent == 100)
    }

    @Test("Completed and invalid targets never produce another milestone")
    func completion() {
        for amount: Decimal in [50_000_000, 60_000_000] {
            let goal = snapshot(amount: amount)
            #expect(goal.isComplete)
            #expect(goal.progress == 1)
            #expect(goal.remainingAmount == 0)
            #expect(goal.nextMilestonePercent == nil)
        }
        #expect(snapshot(amount: 0, target: 0).progress == 0)
        #expect(snapshot(amount: 0, target: 0).nextMilestonePercent == nil)
    }

    @Test("Pinned widgets retain identity and never switch after deletion or archiving")
    func selection() throws {
        let defaults = try #require(UserDefaults(suiteName: "goal-widget-\(UUID())"))
        defer { defaults.removeObject(forKey: GoalWidgetStore.storageKey) }
        let store = GoalWidgetStore(defaults: defaults)
        let first = snapshot(amount: 10_000_000)
        let second = snapshot(amount: 30_000_000)
        #expect(try store.save([first, second]))
        #expect(try !store.save([first, second]))
        #expect(store.selected(id: first.id) == first)
        #expect(store.selected(id: nil) == nil)
        try store.save([second])
        #expect(store.selected(id: first.id) == nil)
        try store.save([
            GoalWidgetSnapshot(
                id: second.id, name: second.name,
                targetAmount: second.targetAmount, earmarkedAmount: second.earmarkedAmount,
                symbolName: second.symbolName, colorName: second.colorName, isArchived: true)
        ])
        #expect(store.selected(id: second.id) == nil)
        try store.save([])
        #expect(store.load().isEmpty)
    }

    @Test("Projection follows saved contributions, renames, archiving and deletion")
    func projection() throws {
        let container = try ModelContainer(
            for: FinancialGoal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let goal = FinancialGoal(
            id: UUID(), name: "Japan", targetAmount: 50_000_000,
            earmarkedAmount: 10_000_000, targetDate: .now, monthlyContribution: 9_000_000,
            fundingJarID: nil, symbolName: "airplane", colorName: "mauve", createdAt: .now)
        context.insert(goal)
        try context.save()
        #expect(try GoalWidgetSnapshot.make(in: context).first?.earmarkedAmount == 10_000_000)
        try GoalContributionStore.record(amount: 5_000_000, on: goal, id: UUID(), occurredAt: .now)
        goal.name = "Japan holiday"
        try context.save()
        let snapshot = try #require(try GoalWidgetSnapshot.make(in: context).first)
        #expect(snapshot.id == goal.id)
        #expect(snapshot.name == "Japan holiday")
        #expect(snapshot.earmarkedAmount == 15_000_000)
        goal.archivedAt = .now
        try context.save()
        #expect(try GoalWidgetSnapshot.make(in: context).first?.isArchived == true)
        context.delete(goal)
        try context.save()
        #expect(try GoalWidgetSnapshot.make(in: context).isEmpty)
    }

    @Test("Goal links wait for unlock and can request the same goal again")
    func deepLinks() throws {
        let route = AppRoute()
        let id = UUID()
        let url = try #require(URL(string: "monmon-dev://goal/\(id)"))
        #expect(route.receive(url, isLocked: true))
        #expect(route.goalRequestID == nil)
        route.releaseQueuedQuickCapture(isLocked: false)
        #expect(route.goalRequestID == id)
        let revision = route.goalRequestRevision
        route.consumeGoal()
        #expect(route.goalRequestRevision == revision)
        route.consumeGoalTabRequest()
        #expect(route.goalRequestRevision == nil)
        #expect(route.receive(url, isLocked: false))
        #expect(route.goalRequestRevision != revision)
        #expect(route.quickCaptureRequestID == nil)
        #expect(!route.receive(try #require(URL(string: "monmon://goal/invalid")), isLocked: false))
    }
}
