import Foundation

struct TripWorkspaceCollection {
    let usableGoals: [FinancialGoal]
    let activeWorkspaces: [TripWorkspace]
    let completedWorkspaces: [TripWorkspace]

    var usableGoalIDs: [UUID] { usableGoals.map(\.id) }
    var activeWorkspaceIDs: [UUID] { activeWorkspaces.map(\.id) }
    var completedWorkspaceIDs: [UUID] { completedWorkspaces.map(\.id) }

    static func snapshot(
        goals: [FinancialGoal],
        workspaces: [TripWorkspace]
    ) -> TripWorkspaceCollection {
        let startedGoalIDs = Set(workspaces.compactMap(\.sourceGoalID))
        let usableGoals =
            goals
            .filter {
                $0.earmarkedAmount > 0
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
            usableGoals: usableGoals,
            activeWorkspaces: active,
            completedWorkspaces: completed
        )
    }
}

enum SpendingFeaturedTrip {
    static func select(from workspaces: [TripWorkspace]) -> TripWorkspace? {
        workspaces
            .filter { $0.status == .active }
            .max {
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
