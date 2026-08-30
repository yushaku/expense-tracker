import Foundation

struct TripSummarySnapshot: Equatable {
    let budgetAmount: Decimal
    let spentAmount: Decimal
    let remainingAmount: Decimal
    let overBudgetAmount: Decimal
    let categoryBreakdown: [CategoryBreakdownSlice]
    let linkedTransactionIDs: [UUID]
}

enum TripSummary {
    static func snapshot(
        workspace: TripWorkspace,
        transactions: [MoneyTransaction],
        categories: [TransactionCategory]
    ) -> TripSummarySnapshot {
        let linked = linkedExpenses(workspaceID: workspace.id, in: transactions)
        let spent = linked.reduce(Decimal.zero) { $0 + $1.amount }

        return TripSummarySnapshot(
            budgetAmount: workspace.budgetAmount,
            spentAmount: spent,
            remainingAmount: max(0, workspace.budgetAmount - spent),
            overBudgetAmount: max(0, spent - workspace.budgetAmount),
            categoryBreakdown: CategoryBreakdown.slices(
                of: .expense,
                transactions: linked,
                categories: categories
            ),
            linkedTransactionIDs: linked.map(\.id)
        )
    }

    static func linkedExpenses(
        workspaceID: UUID,
        in transactions: [MoneyTransaction]
    ) -> [MoneyTransaction] {
        transactions
            .filter { $0.kind == .expense && $0.tripWorkspaceID == workspaceID }
            .sorted {
                $0.occurredAt == $1.occurredAt
                    ? $0.createdAt > $1.createdAt
                    : $0.occurredAt > $1.occurredAt
            }
    }
}
