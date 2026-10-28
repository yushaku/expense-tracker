import SwiftData
import SwiftUI

private enum TripLifecycleConfirmation: String, Identifiable {
    case archive
    case cancel
    case complete

    var id: String { rawValue }
}

struct GoalSpendingDetailView: View {
    @AppStorage(SpendingFeaturedTrip.pinnedIDKey) private var pinnedTripID = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Every transaction linked to this trip, any kind: the summary keeps
    /// the expenses, and cancelling refuses a trip with anything linked.
    @Query private var tripTransactions: [MoneyTransaction]

    /// The month goal capacity reads, for the goal editor.
    @Query private var capacityMonthTransactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var recurringRules: [RecurringRule]

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    let workspace: TripWorkspace
    let asOf: Date

    init(workspace: TripWorkspace, asOf: Date) {
        self.workspace = workspace
        self.asOf = asOf
        _tripTransactions = Query(LedgerFetch.tripTransactions(workspace.id))
        _capacityMonthTransactions = Query(LedgerFetch.transactions(in: .month(containing: asOf)))
    }

    @State private var editorMode: TransactionEditorMode?
    @State private var goalEditorMode: GoalEditorMode?
    @State private var confirmation: TripLifecycleConfirmation?
    @State private var transactionActions = TransactionActions()
    @State private var saveErrorMessage: LocalizedStringKey?

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            TripDetailContent(
                workspace: workspace,
                goal: sourceGoal,
                tripTransactions: tripTransactions,
                categories: categories,
                accounts: accounts,
                onAddExpense: { editorMode = .addToTrip(workspace) },
                onComplete: { confirmation = .complete },
                onReopen: reopen,
                onCancel: { confirmation = .cancel },
                isArchived: workspace.archivedAt != nil,
                saveErrorMessage: saveErrorMessage
            )
        }
        .navigationTitle(workspace.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if workspace.status == .active && workspace.archivedAt == nil {
                    Button(
                        isPinned ? "Unpin trip" : "Pin trip",
                        systemImage: isPinned ? "pin.slash" : "pin"
                    ) {
                        pinnedTripID = isPinned ? "" : workspace.id.uuidString
                    }
                    .accessibilityHint("Choose the trip shown in Transactions on this device")
                    .accessibilityIdentifier("trip-detail-pin")
                }

                Button("Edit", systemImage: "pencil") {
                    goalEditorMode = .edit(GoalJourney(goal: sourceGoal, workspace: workspace))
                }
                .accessibilityIdentifier("goal-detail-edit")

                if workspace.archivedAt != nil {
                    Button("Restore trip", systemImage: "arrow.uturn.backward.circle") {
                        restore()
                    }
                    .accessibilityIdentifier("trip-detail-restore")
                } else if workspace.status == .completed {
                    Button("Archive trip", systemImage: "archivebox") {
                        confirmation = .archive
                    }
                    .accessibilityIdentifier("trip-detail-archive")
                }
            }
        }
        .appSheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .transactionActions(
            transactionActions,
            category: category(for:),
            account: account(for:),
            onEdit: { editorMode = .edit($0) }
        )
        .appSheet(item: $goalEditorMode) { mode in
            GoalEditorView(mode: mode, capacityByJar: goalCapacityByJar, asOf: asOf)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if confirmation == .archive {
                Button("Archive", role: .destructive) { archive() }
                Button("Cancel", role: .cancel) {}
            } else if confirmation == .complete {
                Button("Complete trip") { complete() }
                Button("Keep active", role: .cancel) {}
            } else {
                Button(
                    sourceGoal == nil ? "Cancel trip workspace" : "Return to saving",
                    role: .destructive
                ) {
                    cancel()
                }
                Button("Keep trip", role: .cancel) {}
            }
        } message: {
            Text(confirmationMessage)
        }
        .tint(MonMonTheme.accent)
        .accessibilityIdentifier("trip-detail-\(workspace.id.uuidString)")
    }

    private var sourceGoal: FinancialGoal? {
        workspace.sourceGoalID.flatMap { goalID in goals.first { $0.id == goalID } }
    }

    private var isPinned: Bool {
        UUID(uuidString: pinnedTripID) == workspace.id
    }

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        transaction.categoryID.flatMap { categoryID in categories.first { $0.id == categoryID } }
    }

    private func account(for transaction: MoneyTransaction) -> CashAccount? {
        accounts.first { $0.id == transaction.accountID }
    }

    private var goalCapacityByJar: [UUID: Decimal] {
        BudgetSummary.goalCapacityByJar(
            monthContaining: asOf,
            asOf: asOf,
            jars: jars,
            recurringRules: recurringRules,
            transactions: capacityMonthTransactions
        )
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
        switch confirmation {
        case .archive:
            "Archive this trip?"
        case .complete:
            "Complete this trip?"
        case .cancel, .none:
            sourceGoal == nil ? "Cancel this trip workspace?" : "Return to saving?"
        }
    }

    private var confirmationMessage: LocalizedStringKey {
        switch confirmation {
        case .archive:
            "The trip moves out of history. Its linked expenses and budget summary stay intact."
        case .complete:
            "The trip moves to history. No account balance or transaction changes."
        case .cancel, .none:
            "The empty spending budget will be removed. Your saved amount and contribution history stay intact."
        }
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

    private func archive() {
        saveErrorMessage = nil
        do {
            try TripWorkspaceLifecycle.archive(workspace, at: .now)
            try SyncWriteGate.save(modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t update this trip. Try again."
        }
    }

    private func restore() {
        saveErrorMessage = nil
        TripWorkspaceLifecycle.restore(workspace)
        saveWorkspaceChange()
    }

    private func saveWorkspaceChange() {
        do {
            try SyncWriteGate.save(modelContext)
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t update this trip. Try again."
        }
    }

    private func cancel() {
        saveErrorMessage = nil
        let returnsToSaving = sourceGoal != nil
        do {
            try TripWorkspaceLifecycle.cancel(
                workspace,
                transactions: tripTransactions,
                in: modelContext
            )
            if !returnsToSaving { dismiss() }
        } catch TripWorkspaceLifecycleError.workspaceHasTransactions {
            saveErrorMessage = "A trip with expenses cannot be cancelled."
        } catch {
            saveErrorMessage = "Couldn’t cancel this trip. Try again."
        }
    }
}

private struct TripDetailContent: View {
    let workspace: TripWorkspace
    let goal: FinancialGoal?
    /// The trip's own rows, already fetched by trip. The summary is worked out
    /// in `body` rather than in `init`: an initializer runs on every rebuild
    /// of the parent, whether or not SwiftUI goes on to need this body.
    let tripTransactions: [MoneyTransaction]
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let onAddExpense: () -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onCancel: () -> Void
    let isArchived: Bool
    let saveErrorMessage: LocalizedStringKey?

    var body: some View {
        let snapshot = TripSummary.snapshot(
            workspace: workspace,
            transactions: tripTransactions,
            categories: categories
        )
        let linkedTransactions = TripSummary.linkedExpenses(
            workspaceID: workspace.id,
            in: tripTransactions
        )

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

                TransactionListSection(
                    title: "Trip expenses",
                    transactions: linkedTransactions,
                    categories: categories,
                    accounts: accounts,
                    emptyNotice: "Record an expense and keep its normal category.",
                    accessibilityIdentifierPrefix: "trip-expense",
                    showsCount: true
                )

                if let goal {
                    GoalSavingsHistoryCard(goal: goal)
                    GoalContributionCard(goal: goal)
                }

                TripLifecycleSection(
                    status: workspace.status,
                    hasSavingsGoal: goal != nil,
                    hasTransactions: !linkedTransactions.isEmpty,
                    remainingAmount: snapshot.remainingAmount,
                    onComplete: onComplete,
                    onReopen: onReopen,
                    onCancel: onCancel,
                    isArchived: isArchived
                )
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, canAddExpense ? FloatingAddButton.contentInset : 16)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            if canAddExpense {
                FloatingAddButton(
                    title: "Add expense",
                    accessibilityIdentifier: "trip-add-expense",
                    usesLiquidGlass: true,
                    action: onAddExpense
                )
            }
        }
    }

    private var canAddExpense: Bool {
        workspace.status == .active && !isArchived && !accounts.isEmpty
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
                        Text("Spending")
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("Completed")
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

private struct GoalSavingsHistoryCard: View {
    @Environment(\.appDateFormat) private var dateFormat
    let goal: FinancialGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Savings history").font(.headline)
            LabeledContent("Target amount", value: VNDCurrency.format(goal.targetAmount))
            LabeledContent("Already earmarked", value: VNDCurrency.format(goal.earmarkedAmount))
            LabeledContent("Target date", value: dateFormat.calendarDay(goal.targetDate))
        }
        .font(.subheadline)
        .appCard()
    }
}

private struct TripLifecycleSection: View {
    let status: TripWorkspaceStatus
    let hasSavingsGoal: Bool
    let hasTransactions: Bool
    let remainingAmount: Decimal
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onCancel: () -> Void
    let isArchived: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status == .active {
                Button("Complete trip", systemImage: "checkmark.circle.fill", action: onComplete)
                    .buttonStyle(.prominentAction)

                if !hasTransactions {
                    Button(
                        hasSavingsGoal ? "Return to saving" : "Cancel trip workspace",
                        systemImage: hasSavingsGoal ? "arrow.uturn.backward" : "trash"
                    ) {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if isArchived {
                Text("Restore this trip before reopening it.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
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
