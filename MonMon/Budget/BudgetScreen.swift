import SwiftData
import SwiftUI

/// The Plan tab. This shell owns the sheets and navigation; everything worked
/// out from the ledger lives in `BudgetContent`, so presenting or dismissing a
/// sheet does not recompute the month.
struct BudgetScreen: View {
    @Environment(AppRoute.self) private var appRoute

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    @State private var isShowingRecurringIncome = false
    @State private var isShowingConfiguration = false
    @State private var isShowingGoals = false
    @State private var isShowingIncomeTimeline = false
    @State private var selectedJarID: UUID?
    @State private var selectedGoalID: UUID?
    @State private var selectedTripID: UUID?
    @State private var selectedMonth: Date?

    /// Today, kept current: refreshed when the screen appears, when the app
    /// comes back to the foreground and when the calendar day changes. A
    /// default of `.now` in `init` froze it at whenever the tab view last
    /// rebuilt the screen, and handed every rebuild a different date.
    @State private var today = Date.now

    /// Set by previews and tests to pin the clock.
    private let fixedAsOf: Date?

    init(asOf: Date? = nil) {
        fixedAsOf = asOf
    }

    private var asOf: Date {
        fixedAsOf ?? today
    }

    private var visibleMonth: Date {
        selectedMonth ?? TransactionPeriod.startOfMonth(for: asOf)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    monthRail

                    BudgetContent(
                        month: visibleMonth,
                        today: asOf,
                        fixedAsOf: fixedAsOf,
                        isShowingIncomeTimeline: $isShowingIncomeTimeline,
                        isShowingConfiguration: $isShowingConfiguration,
                        isShowingRecurringIncome: $isShowingRecurringIncome,
                        isShowingGoals: $isShowingGoals,
                        selectedJarID: $selectedJarID,
                        selectedGoalID: $selectedGoalID,
                        selectedTripID: $selectedTripID
                    )
                }
            }
            .onChange(of: appRoute.goalRequestID, initial: true) { _, id in
                guard let id else { return }
                isShowingGoals = false
                isShowingRecurringIncome = false
                isShowingConfiguration = false
                isShowingIncomeTimeline = false
                selectedJarID = nil
                selectedTripID = nil
                selectedGoalID = id
                appRoute.consumeGoal()
            }
            .rootScreenHeader("Plan")
            .accessibilityIdentifier("budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Setup", systemImage: "slider.horizontal.3") {
                        isShowingConfiguration = true
                    }
                    .buttonStyle(.plain)
                    .headerIconStyle()
                    .accessibilityIdentifier("budget-setup")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Income", systemImage: "arrow.triangle.2.circlepath") {
                        isShowingRecurringIncome = true
                    }
                    .buttonStyle(.plain)
                    .headerIconStyle()
                    .accessibilityIdentifier("budget-income-rules")
                }
            }
            .appSheet(isPresented: $isShowingRecurringIncome) {
                RecurringListView(asOf: asOf)
            }
            .appSheet(isPresented: $isShowingConfiguration) {
                BudgetConfigurationView(asOf: asOf)
            }
            .appSheet(isPresented: $isShowingGoals) {
                SpendingGoalsSheet(asOf: asOf)
            }
            .appSheet(isPresented: $isShowingIncomeTimeline) {
                IncomeAllocationTimelineView(asOf: asOf)
            }
            .navigationDestination(item: $selectedJarID) { jarID in
                BudgetJarDestination(jarID: jarID, month: visibleMonth, fixedAsOf: fixedAsOf)
            }
            .navigationDestination(item: $selectedGoalID) { goalID in
                GoalDetailView(goalID: goalID, asOf: asOf)
            }
            .navigationDestination(item: $selectedTripID) { tripID in
                if let workspace = tripWorkspaces.first(where: { $0.id == tripID }) {
                    GoalDetailView(workspace: workspace, asOf: asOf)
                }
            }
            .tint(MonMonTheme.accent)
        }
        .refreshesCurrentDate($today)
    }

    private var monthRail: some View {
        let range = TransactionRange.month(containing: visibleMonth)
        let periods = PeriodRailPeriods(range: range, today: asOf)

        return PeriodRail(
            unit: periods.unit,
            periods: periods.periods,
            selection: periods.selection
        ) { period in
            selectedMonth = period
        }
        .background(MonMonTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonMonTheme.border)
                .frame(height: 1)
        }
    }
}

/// Everything on Plan computed from the ledger.
///
/// It fetches only the visible month and, when that is another month, the
/// month `asOf` falls in (the goal capacity reads that one). The snapshot,
/// capacity and goal commitments are each worked out once per update; they
/// used to be properties the body evaluated several times over, each pass over
/// the whole ledger.
private struct BudgetContent: View {
    @Environment(\.locale) private var locale

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var recurringRules: [RecurringRule]

    @Query private var monthTransactions: [MoneyTransaction]

    /// The capacity month, fetched only when it is not the visible one.
    @Query private var capacityMonthTransactions: [MoneyTransaction]

    @Query(sort: \SavingsDeposit.openedAt, order: .reverse)
    private var savingsDeposits: [SavingsDeposit]

    @Query(sort: \FundHolding.createdAt, order: .reverse)
    private var fundHoldings: [FundHolding]

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    let month: Date
    /// Today as the shell knows it. Goal cards read this; it also re-runs
    /// this body when the day changes.
    let today: Date
    let fixedAsOf: Date?

    // What this content opens. It only ever writes these, never reads them,
    // so a sheet or push changing them does not re-run this body. Closures
    // would not do: SwiftUI cannot compare them, so every update of the shell
    // would count as a change here.
    @Binding var isShowingIncomeTimeline: Bool
    @Binding var isShowingConfiguration: Bool
    @Binding var isShowingRecurringIncome: Bool
    @Binding var isShowingGoals: Bool
    @Binding var selectedJarID: UUID?
    @Binding var selectedGoalID: UUID?
    @Binding var selectedTripID: UUID?

    private let capacitySharesMonth: Bool

    init(
        month: Date,
        today: Date,
        fixedAsOf: Date?,
        isShowingIncomeTimeline: Binding<Bool>,
        isShowingConfiguration: Binding<Bool>,
        isShowingRecurringIncome: Binding<Bool>,
        isShowingGoals: Binding<Bool>,
        selectedJarID: Binding<UUID?>,
        selectedGoalID: Binding<UUID?>,
        selectedTripID: Binding<UUID?>
    ) {
        self.month = month
        self.today = today
        self.fixedAsOf = fixedAsOf
        _isShowingIncomeTimeline = isShowingIncomeTimeline
        _isShowingConfiguration = isShowingConfiguration
        _isShowingRecurringIncome = isShowingRecurringIncome
        _isShowingGoals = isShowingGoals
        _selectedJarID = selectedJarID
        _selectedGoalID = selectedGoalID
        _selectedTripID = selectedTripID

        let visible = TransactionRange.month(containing: month)
        let capacity = TransactionRange.month(containing: today)
        capacitySharesMonth = visible == capacity
        _monthTransactions = Query(LedgerFetch.transactions(in: visible))
        _capacityMonthTransactions = Query(
            capacitySharesMonth
                ? FetchDescriptor(predicate: #Predicate<MoneyTransaction> { _ in false })
                : LedgerFetch.transactions(in: capacity)
        )
    }

    var body: some View {
        // The ledger cutoff is the moment of this update, as it was when the
        // screen was rebuilt on every change: a row recorded a second ago is
        // counted. `today` only decides which months are fetched.
        let asOf = fixedAsOf ?? .now
        let snapshot = BudgetSummary.snapshot(
            monthContaining: month,
            asOf: asOf,
            jars: jars,
            categories: categories,
            recurringRules: recurringRules,
            transactions: monthTransactions,
            savingsDeposits: savingsDeposits,
            fundHoldings: fundHoldings
        )
        let capacityByJar = BudgetSummary.goalCapacityByJar(
            monthContaining: asOf,
            asOf: asOf,
            jars: jars,
            recurringRules: recurringRules,
            transactions: capacitySharesMonth ? monthTransactions : capacityMonthTransactions
        )
        let commitments = GoalCommitment.snapshots(
            jarIDs: jars.map(\.id),
            goals: goals,
            capacityByJar: capacityByJar
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                Text("Income allocation")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                BudgetIncomeCard(
                    snapshot: snapshot,
                    monthTitle: TransactionPeriod.title(for: month, in: locale),
                    onOpenTimeline: { isShowingIncomeTimeline = true },
                    onOpenSetup: { isShowingConfiguration = true }
                )

                if snapshot.plannedIncome == 0 && snapshot.receivedIncome == 0 {
                    noIncomeCard
                }

                ForEach(snapshot.rowsByAllocation) { row in
                    BudgetJarCard(
                        row: row,
                        goalCommitment: commitments[row.jarID],
                        onOpenDetails: { selectedJarID = row.jarID }
                    )
                }

                goalOverviewSection
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private var inProgressGoals: [FinancialGoal] {
        let startedGoalIDs = Set(tripWorkspaces.compactMap(\.sourceGoalID))
        return goals.filter {
            $0.archivedAt == nil
                && $0.earmarkedAmount < $0.targetAmount
                && !startedGoalIDs.contains($0.id)
        }
    }

    private var completedGoalsAvailableToUse: [FinancialGoal] {
        tripCollection.usableGoals.filter { $0.earmarkedAmount >= $0.targetAmount }
    }

    private var tripCollection: TripWorkspaceCollection {
        TripWorkspaceCollection.snapshot(goals: goals, workspaces: tripWorkspaces)
    }

    private var activeTrips: [TripWorkspace] {
        tripWorkspaces.filter { $0.status == .active }
    }

    private var goalOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isShowingGoals = true
            } label: {
                HStack(spacing: 10) {
                    Text("Goals")
                        .font(.title3.weight(.semibold))

                    Text(
                        (inProgressGoals.count
                            + completedGoalsAvailableToUse.count
                            + activeTrips.count).formatted()
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MonMonTheme.textMuted)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens all goals and goal history")
            .accessibilityIdentifier("budget-goals")

            if inProgressGoals.isEmpty && completedGoalsAvailableToUse.isEmpty
                && activeTrips.isEmpty
            {
                Text("No active or in-progress goals")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(
                        MonMonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(MonMonTheme.border, lineWidth: 1)
                    }
            } else {
                inProgressGoalList
                usableGoalList
                activeTripList
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("budget-goal-overview")
    }

    @ViewBuilder
    private var usableGoalList: some View {
        if !completedGoalsAvailableToUse.isEmpty {
            Text("Ready to use")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            ForEach(completedGoalsAvailableToUse) { goal in
                goalButton(goal)
            }
        }
    }

    @ViewBuilder
    private var inProgressGoalList: some View {
        if !inProgressGoals.isEmpty {
            Text("Accumulating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            ForEach(inProgressGoals) { goal in
                goalButton(goal)
            }
        }
    }

    @ViewBuilder
    private var activeTripList: some View {
        if !activeTrips.isEmpty {
            Text("Active")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            ForEach(activeTrips) { workspace in
                Button {
                    selectedTripID = workspace.id
                } label: {
                    BudgetTripCard(workspace: workspace, categories: categories)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this trip workspace")
                .accessibilityIdentifier("budget-active-trip-\(workspace.id.uuidString)")
            }
        }
    }

    private func jarName(_ id: UUID) -> String? {
        jars.first { $0.id == id }?.name
    }

    private func goalButton(_ goal: FinancialGoal) -> some View {
        Button {
            selectedGoalID = goal.id
        } label: {
            GoalCard(
                goal: goal,
                jarName: goal.fundingJarID.flatMap(jarName)
                    ?? String(localized: "No jar"),
                asOf: today
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this goal's details")
        .accessibilityIdentifier("budget-goal-\(goal.id.uuidString)")
    }

    private var noIncomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No monthly income planned", systemImage: "calendar.badge.plus")
                .font(.headline)

            Text("Add salary or another recurring income so Budget can plan the month ahead.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Button("Add recurring income") {
                isShowingRecurringIncome = true
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("budget-add-income")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}

/// An active trip's card, summed from its own linked expenses rather than a
/// pass over the whole ledger per trip.
private struct BudgetTripCard: View {
    let workspace: TripWorkspace
    let categories: [TransactionCategory]

    @Query private var linked: [MoneyTransaction]

    init(workspace: TripWorkspace, categories: [TransactionCategory]) {
        self.workspace = workspace
        self.categories = categories
        _linked = Query(LedgerFetch.tripTransactions(workspace.id))
    }

    var body: some View {
        TripWorkspaceCard(
            workspace: workspace,
            snapshot: TripSummary.snapshot(
                workspace: workspace,
                transactions: linked,
                categories: categories
            )
        )
    }
}

/// A jar's detail screen, with the jar's row worked out from the month it is
/// about. The row used to come from the Plan screen's snapshot, which the
/// shell no longer computes; this keeps it live the same way, by its own
/// month-scoped query.
private struct BudgetJarDestination: View {
    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var recurringRules: [RecurringRule]

    @Query private var monthTransactions: [MoneyTransaction]

    @Query(sort: \SavingsDeposit.openedAt, order: .reverse)
    private var savingsDeposits: [SavingsDeposit]

    @Query(sort: \FundHolding.createdAt, order: .reverse)
    private var fundHoldings: [FundHolding]

    let jarID: UUID
    let month: Date
    let fixedAsOf: Date?

    init(jarID: UUID, month: Date, fixedAsOf: Date?) {
        self.jarID = jarID
        self.month = month
        self.fixedAsOf = fixedAsOf
        _monthTransactions = Query(LedgerFetch.transactions(in: .month(containing: month)))
    }

    var body: some View {
        let asOf = fixedAsOf ?? .now
        let snapshot = BudgetSummary.snapshot(
            monthContaining: month,
            asOf: asOf,
            jars: jars,
            categories: categories,
            recurringRules: recurringRules,
            transactions: monthTransactions,
            savingsDeposits: savingsDeposits,
            fundHoldings: fundHoldings
        )

        if let row = snapshot.rows.first(where: { $0.jarID == jarID }) {
            BudgetJarDetailView(row: row, month: month, asOf: asOf)
        }
    }
}

#if DEBUG
    #Preview("Budget") {
        let container = PreviewData.populated
        BudgetJarSeed.seedIfNeeded(
            in: container.mainContext,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            locale: Locale(identifier: "en")
        )
        return BudgetScreen(asOf: Date(timeIntervalSince1970: 1_700_000_000))
            .environment(AppRoute())
            .modelContainer(container)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
