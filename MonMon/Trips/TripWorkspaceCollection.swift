import Foundation
import SwiftData

/// One user-facing goal throughout accumulation and spending. The existing storage
/// records keep their IDs so backups, sync and transaction links remain compatible.
struct GoalJourney {
    let goal: FinancialGoal?
    var workspace: TripWorkspace? = nil

    @MainActor
    func save(
        draft: FinancialGoalDraft, jars: [BudgetJar], goals: [FinancialGoal],
        capacityByJar: [UUID: Decimal], asOf: Date, in context: ModelContext
    ) throws {
        let restoreGoal = goal.map { goal in
            let identity = (goal.name, goal.symbolName, goal.colorName, goal.fundingJarID)
            let plan = (
                goal.targetAmount, goal.earmarkedAmount, goal.targetDate, goal.monthlyContribution
            )
            return {
                (goal.name, goal.symbolName, goal.colorName, goal.fundingJarID) = identity
                (
                    goal.targetAmount, goal.earmarkedAmount, goal.targetDate,
                    goal.monthlyContribution
                ) = plan
            }
        }
        let restoreWorkspace = workspace.map { workspace in
            let identity = (
                workspace.name, workspace.symbolName, workspace.colorName, workspace.fundingJarID
            )
            let budget = workspace.budgetAmount
            return {
                (
                    workspace.name, workspace.symbolName, workspace.colorName,
                    workspace.fundingJarID
                ) = identity
                workspace.budgetAmount = budget
            }
        }

        // Validation completes before either model changes.
        try draft.apply(
            to: self, jars: jars, goals: goals, capacityByJar: capacityByJar, asOf: asOf)
        do {
            try SyncWriteGate.save(context)
        } catch {
            context.rollback()
            // SwiftData can retain just-mutated values in its live model cache after rollback.
            restoreGoal?()
            restoreWorkspace?()
            throw error
        }
    }

    static func resolve(
        goalID: UUID?, workspaceID: UUID?,
        goals: [FinancialGoal], workspaces: [TripWorkspace]
    ) -> GoalJourney? {
        let workspace =
            workspaces.first { $0.id == workspaceID }
            ?? workspaces.first { goalID != nil && $0.sourceGoalID == goalID }
        let resolvedGoalID = workspace?.sourceGoalID ?? goalID
        let goal = goals.first { $0.id == resolvedGoalID }
        guard goal != nil || workspace != nil else { return nil }
        return GoalJourney(goal: goal, workspace: workspace)
    }
}

struct TripWorkspaceCollection {
    let usableGoals: [FinancialGoal]
    let activeWorkspaces: [TripWorkspace]
    let completedWorkspaces: [TripWorkspace]
    let archivedWorkspaces: [TripWorkspace]

    var usableGoalIDs: [UUID] { usableGoals.map(\.id) }
    var activeWorkspaceIDs: [UUID] { activeWorkspaces.map(\.id) }
    var completedWorkspaceIDs: [UUID] { completedWorkspaces.map(\.id) }
    var archivedWorkspaceIDs: [UUID] { archivedWorkspaces.map(\.id) }

    static func snapshot(
        goals: [FinancialGoal],
        workspaces: [TripWorkspace]
    ) -> TripWorkspaceCollection {
        let startedGoalIDs = Set(workspaces.compactMap(\.sourceGoalID))
        let usableGoals =
            goals
            .filter {
                $0.archivedAt == nil
                    && $0.earmarkedAmount > 0
                    && $0.fundingJarID != nil
                    && !startedGoalIDs.contains($0.id)
            }
            .sorted { $0.createdAt < $1.createdAt }
        let active =
            workspaces
            .filter { $0.status == .active && $0.archivedAt == nil }
            .sorted { $0.startedAt > $1.startedAt }
        let completed =
            workspaces
            .filter { $0.status == .completed && $0.archivedAt == nil }
            .sorted {
                ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt)
            }
        let archived =
            workspaces
            .filter { $0.archivedAt != nil }
            .sorted {
                ($0.archivedAt ?? $0.completedAt ?? $0.startedAt)
                    > ($1.archivedAt ?? $1.completedAt ?? $1.startedAt)
            }

        return TripWorkspaceCollection(
            usableGoals: usableGoals,
            activeWorkspaces: active,
            completedWorkspaces: completed,
            archivedWorkspaces: archived
        )
    }
}

enum SpendingFeaturedTrip {
    // A display preference for this device, independent of the synced trip data.
    static let pinnedIDKey = "trips.pinnedWorkspaceID"

    static func select(from workspaces: [TripWorkspace], pinnedID: UUID? = nil) -> TripWorkspace? {
        let active = workspaces.filter { $0.status == .active && $0.archivedAt == nil }
        if let pinnedID, let pinned = active.first(where: { $0.id == pinnedID }) {
            return pinned
        }
        return active.max {
            if $0.startedAt != $1.startedAt {
                return $0.startedAt < $1.startedAt
            }
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
