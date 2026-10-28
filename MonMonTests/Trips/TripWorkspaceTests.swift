import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Trip workspace")
struct TripWorkspaceTests {
    private let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Either goal or trip entry opens the same journey, including legacy orphan trips")
    func resolvesOneJourney() throws {
        let goal = makeGoal()
        let trip = try TripWorkspaceLifecycle.start(
            goal: goal, existingWorkspaces: [], id: UUID(), startedAt: startedAt)
        let fromGoal = try #require(
            GoalJourney.resolve(
                goalID: goal.id, workspaceID: nil, goals: [goal], workspaces: [trip]))
        let fromTrip = try #require(
            GoalJourney.resolve(
                goalID: nil, workspaceID: trip.id, goals: [goal], workspaces: [trip]))
        #expect(fromGoal.workspace?.id == fromTrip.workspace?.id)
        #expect(fromGoal.goal?.id == fromTrip.goal?.id)
        #expect(
            GoalJourney.resolve(
                goalID: goal.id, workspaceID: nil, goals: [goal], workspaces: [])?.workspace == nil)
        let orphan = try #require(
            GoalJourney.resolve(
                goalID: nil, workspaceID: trip.id, goals: [], workspaces: [trip]))
        #expect(orphan.goal == nil)
        #expect(orphan.workspace?.id == trip.id)
    }

    @Test(
        "Spending edits preserve savings and expenses, even below the amount already spent",
        arguments: [15_000_000, 2_000_000])
    func editSpendingJourney(budget: Int) throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let goal = makeGoal(earmarkedAmount: 12_000_000)
        goal.targetDate = startedAt.addingTimeInterval(-86_400)
        try GoalContributionStore.record(
            amount: 1_000_000, on: goal, id: UUID(), occurredAt: startedAt)
        let history = goal.contributionHistoryData
        container.mainContext.insert(goal)
        let trip = try TripWorkspaceLifecycle.start(
            goal: goal, existingWorkspaces: [], id: UUID(), startedAt: startedAt,
            in: container.mainContext)
        let expense = MoneyTransaction(
            id: UUID(), kind: .expense, amount: 3_000_000, occurredAt: startedAt,
            note: "Hotel", accountID: UUID(), categoryID: nil, sourceRuleID: nil,
            currencyCode: VNDCurrency.code, createdAt: startedAt, tripWorkspaceID: trip.id)
        container.mainContext.insert(expense)
        let journey = GoalJourney(goal: goal, workspace: trip)
        var draft = FinancialGoalDraft(journey: journey)
        draft.name = "  Hoi An  "
        draft.symbolName = "sailboat.fill"
        draft.colorName = "mauve"
        draft.spendingBudgetText = String(budget)
        try journey.save(
            draft: draft, jars: [], goals: [goal], capacityByJar: [:], asOf: startedAt,
            in: container.mainContext)

        let context = ModelContext(container)
        let storedGoal = try #require(try context.fetch(FetchDescriptor<FinancialGoal>()).first)
        let storedTrip = try #require(try context.fetch(FetchDescriptor<TripWorkspace>()).first)
        #expect(storedGoal.name == "Hoi An")
        #expect(storedTrip.name == storedGoal.name)
        #expect(storedTrip.symbolName == storedGoal.symbolName)
        #expect(storedTrip.colorName == storedGoal.colorName)
        #expect(storedTrip.id == trip.id)
        #expect(storedTrip.sourceGoalID == goal.id)
        #expect(storedTrip.budgetAmount == Decimal(budget))
        #expect(storedTrip.status == .active)
        #expect(storedGoal.targetAmount == 30_000_000)
        #expect(storedGoal.earmarkedAmount == 13_000_000)
        #expect(storedGoal.contributionHistoryData == history)
        #expect(storedGoal.targetDate == goal.targetDate)
        let storedExpenses = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(storedExpenses.count == 1)
        #expect(storedExpenses.first?.tripWorkspaceID == trip.id)
        let summary = TripSummary.snapshot(
            workspace: storedTrip, transactions: storedExpenses, categories: [])
        #expect(summary.spentAmount == 3_000_000)
        #expect(summary.overBudgetAmount == max(0, 3_000_000 - Decimal(budget)))
    }

    @Test(
        "Invalid spending edits leave both records unchanged",
        arguments: [
            ("New name", "0", FinancialGoalFormError.invalidSpendingBudget),
            ("New name", "invalid", FinancialGoalFormError.invalidSpendingBudget),
            (" \n\t", "10000000", FinancialGoalFormError.emptyName),
        ])
    func invalidJourneyEditIsAtomic(name: String, budget: String, error: FinancialGoalFormError)
        throws
    {
        let goal = makeGoal()
        let trip = try TripWorkspaceLifecycle.start(
            goal: goal, existingWorkspaces: [], id: UUID(), startedAt: startedAt)
        let journey = GoalJourney(goal: goal, workspace: trip)
        var draft = FinancialGoalDraft(journey: journey)
        draft.name = name
        draft.spendingBudgetText = budget
        #expect(throws: error) {
            try draft.apply(
                to: journey, jars: [], goals: [goal], capacityByJar: [:], asOf: startedAt)
        }
        #expect(goal.name == "Da Nang")
        #expect(trip.name == "Da Nang")
        #expect(trip.budgetAmount == 30_000_000)
    }

    @Test("Completed orphan journeys remain editable without inventing a savings goal")
    func editOrphanJourney() throws {
        let trip = workspace(status: .completed, archivedAt: startedAt)
        let journey = GoalJourney(goal: nil, workspace: trip)
        var draft = FinancialGoalDraft(journey: journey)
        draft.name = "Old holiday"
        try draft.apply(to: journey, jars: [], goals: [], capacityByJar: [:], asOf: startedAt)
        #expect(trip.name == "Old holiday")
        #expect(trip.budgetAmount == 30_000_000)
        #expect(trip.sourceGoalID == nil)
        #expect(trip.status == .completed)
        #expect(trip.archivedAt == startedAt)
    }

    @Test("A partially funded goal starts a workspace with its accumulated amount")
    func partiallyFundedGoalStartsWorkspace() throws {
        let goal = makeGoal(earmarkedAmount: 12_000_000)
        let workspaceID = UUID()

        let workspace = try TripWorkspaceLifecycle.start(
            goal: goal,
            existingWorkspaces: [],
            id: workspaceID,
            startedAt: startedAt
        )
        goal.targetAmount = 40_000_000

        #expect(workspace.id == workspaceID)
        #expect(workspace.sourceGoalID == goal.id)
        #expect(workspace.name == "Da Nang")
        #expect(workspace.budgetAmount == 12_000_000)
        #expect(workspace.fundingJarID == BudgetJarSeed.savingsID)
        #expect(workspace.symbolName == "airplane")
        #expect(workspace.colorName == "sky")
        #expect(workspace.status == .active)
        #expect(workspace.startedAt == startedAt)
        #expect(workspace.completedAt == nil)
        #expect(workspace.archivedAt == nil)
        #expect(workspace.createdAt == startedAt)
    }

    @Test("An empty or jar-less goal cannot start spending")
    func ineligibleGoalsAreRejected() {
        let empty = makeGoal(earmarkedAmount: 0)
        #expect(throws: TripWorkspaceLifecycleError.goalHasNoFunds) {
            _ = try TripWorkspaceLifecycle.start(
                goal: empty, existingWorkspaces: [], id: UUID(), startedAt: startedAt)
        }

        let jarless = makeGoal(fundingJarID: nil)
        #expect(throws: TripWorkspaceLifecycleError.missingFundingJar) {
            _ = try TripWorkspaceLifecycle.start(
                goal: jarless, existingWorkspaces: [], id: UUID(), startedAt: startedAt)
        }
    }

    @Test("A source goal can start at most one workspace")
    func duplicateSourceGoalIsRejected() throws {
        let goal = makeGoal()
        let existing = try TripWorkspaceLifecycle.start(
            goal: goal,
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt
        )

        #expect(throws: TripWorkspaceLifecycleError.workspaceAlreadyExists) {
            _ = try TripWorkspaceLifecycle.start(
                goal: goal,
                existingWorkspaces: [existing],
                id: UUID(),
                startedAt: startedAt
            )
        }
    }

    @Test("Completing and reopening only change workspace state")
    func completeAndReopenWorkspace() throws {
        let goal = makeGoal()
        let originalGoalAmount = goal.earmarkedAmount
        let workspace = try TripWorkspaceLifecycle.start(
            goal: goal,
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt
        )
        let completedAt = startedAt.addingTimeInterval(86_400)

        TripWorkspaceLifecycle.complete(workspace, at: completedAt)

        #expect(workspace.status == .completed)
        #expect(workspace.completedAt == completedAt)
        #expect(goal.earmarkedAmount == originalGoalAmount)

        TripWorkspaceLifecycle.reopen(workspace)

        #expect(workspace.status == .active)
        #expect(workspace.completedAt == nil)
        #expect(goal.earmarkedAmount == originalGoalAmount)
    }

    @Test("Only completed trips can be archived and restored")
    func archiveCompletedWorkspace() throws {
        let workspace = try TripWorkspaceLifecycle.start(
            goal: makeGoal(),
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt
        )
        let archivedAt = startedAt.addingTimeInterval(172_800)

        #expect(throws: TripWorkspaceLifecycleError.workspaceNotCompleted) {
            try TripWorkspaceLifecycle.archive(workspace, at: archivedAt)
        }

        TripWorkspaceLifecycle.complete(workspace, at: startedAt.addingTimeInterval(86_400))
        try TripWorkspaceLifecycle.archive(workspace, at: archivedAt)

        #expect(workspace.archivedAt == archivedAt)

        TripWorkspaceLifecycle.restore(workspace)

        #expect(workspace.archivedAt == nil)
    }

    @Test("A workspace persists through the shared MonMon schema")
    func workspacePersists() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let goal = makeGoal()
        let workspace = try TripWorkspaceLifecycle.start(
            goal: goal,
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt,
            in: container.mainContext
        )

        let stored = try #require(
            try container.mainContext.fetch(FetchDescriptor<TripWorkspace>()).first)
        #expect(stored.id == workspace.id)
        #expect(stored.sourceGoalID == goal.id)
        #expect(stored.budgetAmount == 30_000_000)
        #expect(stored.status == .active)
        #expect(stored.completedAt == nil)
        #expect(stored.archivedAt == nil)
    }

    @Test("Only an empty active workspace can be cancelled")
    func cancellationProtectsLinkedTransactions() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let workspace = try TripWorkspaceLifecycle.start(
            goal: makeGoal(),
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt
        )
        container.mainContext.insert(workspace)
        try container.mainContext.save()

        let linked = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 100_000,
            occurredAt: startedAt,
            note: "Coffee",
            accountID: UUID(),
            categoryID: UUID(),
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: startedAt,
            tripWorkspaceID: workspace.id
        )
        container.mainContext.insert(linked)
        try container.mainContext.save()

        #expect(throws: TripWorkspaceLifecycleError.workspaceHasTransactions) {
            try TripWorkspaceLifecycle.cancel(
                workspace,
                transactions: [linked],
                in: container.mainContext
            )
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TripWorkspace>()) == 1)

        container.mainContext.delete(linked)
        try container.mainContext.save()
        try TripWorkspaceLifecycle.cancel(
            workspace,
            transactions: [],
            in: container.mainContext
        )

        #expect(try container.mainContext.fetchCount(FetchDescriptor<TripWorkspace>()) == 0)
    }

    @Test("Completed workspaces cannot be cancelled")
    func completedWorkspaceCannotBeCancelled() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let workspace = try TripWorkspaceLifecycle.start(
            goal: makeGoal(),
            existingWorkspaces: [],
            id: UUID(),
            startedAt: startedAt
        )
        TripWorkspaceLifecycle.complete(workspace, at: startedAt)
        container.mainContext.insert(workspace)
        try container.mainContext.save()

        #expect(throws: TripWorkspaceLifecycleError.workspaceNotActive) {
            try TripWorkspaceLifecycle.cancel(
                workspace,
                transactions: [],
                in: container.mainContext
            )
        }
    }

    @Test("Workspace collection separates active completed and archived trips")
    func collectionSeparatesArchivedTrips() {
        let active = workspace(status: .active)
        let completed = workspace(status: .completed)
        let archived = workspace(status: .completed, archivedAt: startedAt)

        let snapshot = TripWorkspaceCollection.snapshot(
            goals: [],
            workspaces: [active, completed, archived]
        )

        #expect(snapshot.activeWorkspaceIDs == [active.id])
        #expect(snapshot.completedWorkspaceIDs == [completed.id])
        #expect(snapshot.archivedWorkspaceIDs == [archived.id])
    }

    private func workspace(
        status: TripWorkspaceStatus,
        archivedAt: Date? = nil
    ) -> TripWorkspace {
        TripWorkspace(
            id: UUID(),
            sourceGoalID: nil,
            name: "Da Nang",
            budgetAmount: 30_000_000,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
            status: status,
            startedAt: startedAt,
            completedAt: status == .completed ? startedAt : nil,
            archivedAt: archivedAt,
            createdAt: startedAt
        )
    }

    private func makeGoal(
        earmarkedAmount: Decimal = 30_000_000,
        fundingJarID: UUID? = BudgetJarSeed.savingsID
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Da Nang",
            targetAmount: 30_000_000,
            earmarkedAmount: earmarkedAmount,
            targetDate: Date(timeIntervalSince1970: 1_900_000_000),
            monthlyContribution: 2_000_000,
            fundingJarID: fundingJarID,
            symbolName: "airplane",
            colorName: "sky",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
