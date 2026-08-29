import Foundation
import SwiftData

enum TripWorkspaceLifecycleError: Error, Equatable {
    case goalHasNoFunds
    case missingFundingJar
    case workspaceAlreadyExists
    case workspaceHasTransactions
    case workspaceNotActive
}

enum TripWorkspaceLifecycle {
    static func start(
        goal: FinancialGoal,
        existingWorkspaces: [TripWorkspace],
        id: UUID,
        startedAt: Date
    ) throws -> TripWorkspace {
        guard goal.earmarkedAmount > 0 else {
            throw TripWorkspaceLifecycleError.goalHasNoFunds
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
            budgetAmount: goal.earmarkedAmount,
            fundingJarID: goal.fundingJarID,
            symbolName: goal.symbolName,
            colorName: goal.colorName,
            status: .active,
            startedAt: startedAt,
            completedAt: nil,
            createdAt: startedAt
        )
    }

    @MainActor
    @discardableResult
    static func start(
        goal: FinancialGoal,
        existingWorkspaces: [TripWorkspace],
        id: UUID,
        startedAt: Date,
        in context: ModelContext
    ) throws -> TripWorkspace {
        let workspace = try start(
            goal: goal,
            existingWorkspaces: existingWorkspaces,
            id: id,
            startedAt: startedAt
        )
        context.insert(workspace)
        do {
            try context.save()
            return workspace
        } catch {
            context.rollback()
            throw error
        }
    }

    static func complete(_ workspace: TripWorkspace, at completedAt: Date) {
        workspace.status = .completed
        workspace.completedAt = completedAt
    }

    static func reopen(_ workspace: TripWorkspace) {
        workspace.status = .active
        workspace.completedAt = nil
    }

    @MainActor
    static func cancel(
        _ workspace: TripWorkspace,
        transactions: [MoneyTransaction],
        in context: ModelContext
    ) throws {
        guard workspace.status == .active else {
            throw TripWorkspaceLifecycleError.workspaceNotActive
        }
        guard !transactions.contains(where: { $0.tripWorkspaceID == workspace.id }) else {
            throw TripWorkspaceLifecycleError.workspaceHasTransactions
        }

        context.delete(workspace)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
