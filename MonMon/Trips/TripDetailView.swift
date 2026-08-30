import SwiftData
import SwiftUI

private enum TripLifecycleConfirmation: String, Identifiable {
    case cancel
    case complete

    var id: String { rawValue }
}

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    let workspace: TripWorkspace

    @State private var editorMode: TransactionEditorMode?
    @State private var confirmation: TripLifecycleConfirmation?
    @State private var saveErrorMessage: LocalizedStringKey?

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            TripDetailContent(
                workspace: workspace,
                transactions: transactions,
                categories: categories,
                accounts: accounts,
                onAddExpense: { editorMode = .addToTrip(workspace) },
                onEditTransaction: { editorMode = .edit($0) },
                onComplete: { confirmation = .complete },
                onReopen: reopen,
                onCancel: { confirmation = .cancel },
                saveErrorMessage: saveErrorMessage
            )
        }
        .navigationTitle(workspace.name)
        .appSheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if confirmation == .complete {
                Button("Complete trip") { complete() }
                Button("Keep active", role: .cancel) {}
            } else {
                Button("Cancel trip workspace", role: .destructive) { cancel() }
                Button("Keep trip", role: .cancel) {}
            }
        } message: {
            Text(confirmationMessage)
        }
        .tint(MonMonTheme.accent)
        .accessibilityIdentifier("trip-detail-\(workspace.id.uuidString)")
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { isPresented in
                if !isPresented {
                    confirmation = nil
                }
            }
        )
    }

    private var confirmationTitle: LocalizedStringKey {
        confirmation == .complete ? "Complete this trip?" : "Cancel this trip workspace?"
    }

    private var confirmationMessage: LocalizedStringKey {
        confirmation == .complete
            ? "The trip moves to history. No account balance or transaction changes."
            : "This removes the empty workspace only. The funded goal remains ready to spend."
    }

    private func complete() {
        saveErrorMessage = nil
        TripWorkspaceLifecycle.complete(workspace, at: .now)
        saveWorkspaceChange()
    }

    private func reopen() {
        saveErrorMessage = nil
        TripWorkspaceLifecycle.reopen(workspace)
        saveWorkspaceChange()
    }

    private func saveWorkspaceChange() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t update this trip. Try again."
        }
    }

    private func cancel() {
        saveErrorMessage = nil
        do {
            try TripWorkspaceLifecycle.cancel(
                workspace,
                transactions: transactions,
                in: modelContext
            )
            dismiss()
        } catch TripWorkspaceLifecycleError.workspaceHasTransactions {
            saveErrorMessage = "A trip with expenses cannot be cancelled."
        } catch {
            saveErrorMessage = "Couldn’t cancel this trip. Try again."
        }
    }
}

private struct TripDetailContent: View {
    let workspace: TripWorkspace
    let snapshot: TripSummarySnapshot
    let linkedTransactions: [MoneyTransaction]
    let categoriesByID: [UUID: TransactionCategory]
    let accountsByID: [UUID: CashAccount]
    let onAddExpense: () -> Void
    let onEditTransaction: (MoneyTransaction) -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onCancel: () -> Void
    let saveErrorMessage: LocalizedStringKey?

    init(
        workspace: TripWorkspace,
        transactions: [MoneyTransaction],
        categories: [TransactionCategory],
        accounts: [CashAccount],
        onAddExpense: @escaping () -> Void,
        onEditTransaction: @escaping (MoneyTransaction) -> Void,
        onComplete: @escaping () -> Void,
        onReopen: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        saveErrorMessage: LocalizedStringKey?
    ) {
        self.workspace = workspace
        snapshot = TripSummary.snapshot(
            workspace: workspace,
            transactions: transactions,
            categories: categories
        )
        linkedTransactions = TripSummary.linkedExpenses(
            workspaceID: workspace.id,
            in: transactions
        )
        categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        accountsByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        self.onAddExpense = onAddExpense
        self.onEditTransaction = onEditTransaction
        self.onComplete = onComplete
        self.onReopen = onReopen
        self.onCancel = onCancel
        self.saveErrorMessage = saveErrorMessage
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                TripSummarySection(workspace: workspace, snapshot: snapshot)

                if let saveErrorMessage {
                    TripErrorBanner(message: saveErrorMessage)
                }

                CategoryBreakdownCard(
                    kind: .constant(.expense),
                    slices: snapshot.categoryBreakdown,
                    showsKindPicker: false,
                    emptyStateMessage:
                        "Food, accommodation, transport, and other spending will appear here."
                )

                TripTransactionSection(
                    transactions: linkedTransactions,
                    categoriesByID: categoriesByID,
                    accountsByID: accountsByID,
                    onAddExpense: workspace.status == .active ? onAddExpense : nil,
                    onEdit: onEditTransaction
                )

                TripLifecycleSection(
                    status: workspace.status,
                    hasTransactions: !linkedTransactions.isEmpty,
                    remainingAmount: snapshot.remainingAmount,
                    onComplete: onComplete,
                    onReopen: onReopen,
                    onCancel: onCancel
                )
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TripSummarySection: View {
    let workspace: TripWorkspace
    let snapshot: TripSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: CategoryPalette.symbolName(workspace.symbolName))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    if workspace.status == .active {
                        Text("Active trip")
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("Completed trip")
                            .font(.title3.weight(.semibold))
                    }
                    Text("Only linked expenses reduce this budget.")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                TripMetric(title: "Budget", amount: snapshot.budgetAmount)
                TripMetric(title: "Spent", amount: snapshot.spentAmount)
                TripMetric(
                    title: snapshot.overBudgetAmount > 0 ? "Over budget" : "Left to spend",
                    amount: snapshot.overBudgetAmount > 0
                        ? snapshot.overBudgetAmount : snapshot.remainingAmount,
                    isWarning: snapshot.overBudgetAmount > 0
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var tint: Color {
        CategoryPalette.color(named: workspace.colorName)
    }
}

private struct TripTransactionSection: View {
    let transactions: [MoneyTransaction]
    let categoriesByID: [UUID: TransactionCategory]
    let accountsByID: [UUID: CashAccount]
    let onAddExpense: (() -> Void)?
    let onEdit: (MoneyTransaction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trip expenses")
                    .font(.title3.weight(.semibold))

                Spacer(minLength: 12)

                if let onAddExpense {
                    Button("Add expense", systemImage: "plus", action: onAddExpense)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("trip-add-expense")
                }
            }

            if transactions.isEmpty {
                ContentUnavailableView(
                    "No trip expenses",
                    systemImage: "receipt",
                    description: Text("Record an expense and keep its normal category.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(transactions) { transaction in
                    Button {
                        onEdit(transaction)
                    } label: {
                        TransactionCard(
                            transaction: transaction,
                            category: transaction.categoryID.flatMap { categoriesByID[$0] },
                            account: accountsByID[transaction.accountID]
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this trip expense for editing")
                }
            }
        }
    }
}

private struct TripLifecycleSection: View {
    let status: TripWorkspaceStatus
    let hasTransactions: Bool
    let remainingAmount: Decimal
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status == .active {
                Button("Complete trip", systemImage: "checkmark.circle.fill", action: onComplete)
                    .buttonStyle(.prominentAction)

                if !hasTransactions {
                    Button("Cancel trip workspace", systemImage: "trash", role: .destructive) {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Text(
                    "The unused \(VNDCurrency.format(remainingAmount)) is available to plan again. No refund or transfer was created."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

                Button("Reopen trip", systemImage: "arrow.uturn.backward", action: onReopen)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TripErrorBanner: View {
    let message: LocalizedStringKey

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.danger)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }
}
