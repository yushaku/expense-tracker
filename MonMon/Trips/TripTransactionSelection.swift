import Foundation

enum TripTransactionSelection {
    static func availableWorkspaces(
        _ workspaces: [TripWorkspace],
        selectedID: UUID?
    ) -> [TripWorkspace] {
        let active =
            workspaces
            .filter { $0.status == .active }
            .sorted { $0.startedAt > $1.startedAt }

        guard
            let selected = workspaces.first(where: {
                $0.id == selectedID && $0.status == .completed
            })
        else {
            return active
        }
        return active + [selected]
    }

    static func apply(
        workspaceID: UUID?,
        workspaces: [TripWorkspace],
        to draft: inout TransactionDraft
    ) {
        guard let workspace = workspaces.first(where: { $0.id == workspaceID }) else {
            draft.tripWorkspaceID = nil
            draft.budgetJarOverrideID = nil
            return
        }

        draft.tripWorkspaceID = workspace.id
        draft.budgetJarOverrideID = workspace.fundingJarID
    }
}
