import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Trip workspace")
struct TripWorkspaceTests {
    private let startedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A partially funded general goal starts a workspace with its accumulated amount")
    func partiallyFundedGeneralGoalStartsWorkspace() throws {
        let goal = makeGoal(kind: .custom, earmarkedAmount: 12_000_000)
        let workspaceID = UUID()

        let workspace = try TripWorkspaceLifecycle.start(
            goal: goal,
            existingWorkspaces: [],
            id: workspaceID,
            startedAt: startedAt
        )
        goal.name = "Renamed goal"
        goal.targetAmount = 40_000_000
        goal.symbolName = "sailboat.fill"

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

    private func makeGoal(
        kind: FinancialGoalKind = .trip,
        earmarkedAmount: Decimal = 30_000_000,
        fundingJarID: UUID? = BudgetJarSeed.savingsID
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Da Nang",
            kind: kind,
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
