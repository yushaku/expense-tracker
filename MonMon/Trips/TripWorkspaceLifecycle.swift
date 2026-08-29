import Foundation

enum TripWorkspaceLifecycleError: Error, Equatable {
    case goalNotFullyFunded
    case missingFundingJar
    case notTripGoal
    case workspaceAlreadyExists
}

enum TripWorkspaceLifecycle {
    static func start(
        goal: FinancialGoal,
        existingWorkspaces: [TripWorkspace],
        id: UUID,
        startedAt: Date
    ) throws -> TripWorkspace {
        guard goal.kind == .trip else {
            throw TripWorkspaceLifecycleError.notTripGoal
        }
        guard goal.targetAmount > 0, goal.earmarkedAmount >= goal.targetAmount else {
            throw TripWorkspaceLifecycleError.goalNotFullyFunded
        }
        guard goal.fundingJarID != nil else {
            throw TripWorkspaceLifecycleError.missingFundingJar
        }
        guard !existingWorkspaces.contains(where: { $0.sourceGoalID == goal.id }) else {
            throw TripWorkspaceLifecycleError.workspaceAlreadyExists
        }

        return TripWorkspace(
            id: id,
            sourceGoalID: goal.id,
            name: goal.name,
            budgetAmount: goal.targetAmount,
            fundingJarID: goal.fundingJarID,
            symbolName: goal.symbolName,
            colorName: goal.colorName,
            status: .active,
            startedAt: startedAt,
            completedAt: nil,
            createdAt: startedAt
        )
    }

    static func complete(_ workspace: TripWorkspace, at completedAt: Date) {
        workspace.status = .completed
        workspace.completedAt = completedAt
    }

    static func reopen(_ workspace: TripWorkspace) {
        workspace.status = .active
        workspace.completedAt = nil
    }
}
