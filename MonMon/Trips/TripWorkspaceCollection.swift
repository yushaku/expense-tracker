import Foundation

struct TripWorkspaceCollection {
    let readyGoals: [FinancialGoal]
    let activeWorkspaces: [TripWorkspace]
    let completedWorkspaces: [TripWorkspace]

    var readyGoalIDs: [UUID] { readyGoals.map(\.id) }
    var activeWorkspaceIDs: [UUID] { activeWorkspaces.map(\.id) }
    var completedWorkspaceIDs: [UUID] { completedWorkspaces.map(\.id) }

    static func snapshot(
        goals: [FinancialGoal],
        workspaces: [TripWorkspace]
    ) -> TripWorkspaceCollection {
        let startedGoalIDs = Set(workspaces.compactMap(\.sourceGoalID))
        let readyGoals =
            goals
            .filter {
                $0.kind == .trip
                    && $0.targetAmount > 0
                    && $0.earmarkedAmount >= $0.targetAmount
                    && $0.fundingJarID != nil
                    && !startedGoalIDs.contains($0.id)
            }
            .sorted { $0.createdAt < $1.createdAt }
        let active =
            workspaces
            .filter { $0.status == .active }
            .sorted { $0.startedAt > $1.startedAt }
        let completed =
            workspaces
            .filter { $0.status == .completed }
            .sorted {
                ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt)
            }

        return TripWorkspaceCollection(
            readyGoals: readyGoals,
            activeWorkspaces: active,
            completedWorkspaces: completed
        )
    }
}
