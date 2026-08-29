import SwiftData
import SwiftUI

struct BudgetScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var recurringRules: [RecurringRule]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \SavingsDeposit.openedAt, order: .reverse)
    private var savingsDeposits: [SavingsDeposit]

    @Query(sort: \FundHolding.createdAt, order: .reverse)
    private var fundHoldings: [FundHolding]

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    @State private var isShowingRecurringIncome = false
    @State private var isShowingConfiguration = false
    @State private var isShowingGoals = false
    @State private var isShowingIncomeTimeline = false
    @State private var selectedJarID: UUID?
    @State private var selectedGoalID: UUID?
    @State private var selectedMonth: Date?
    @State private var startErrorMessage: LocalizedStringKey?

    private let asOf: Date

    init(asOf: Date = .now) {
        self.asOf = asOf
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    monthRail

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                            BudgetIncomeCard(
                                snapshot: snapshot,
                                monthTitle: monthTitle,
                                onOpenTimeline: { isShowingIncomeTimeline = true }
                            )

                            if snapshot.plannedIncome == 0 && snapshot.receivedIncome == 0 {
                                noIncomeCard
                            }

                            ForEach(snapshot.rowsByAllocation) { row in
                                BudgetJarCard(
                                    row: row,
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
            }
            .compactRootNavigationTitle("Budget")
            .accessibilityIdentifier("budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Setup", systemImage: "slider.horizontal.3") {
                        isShowingConfiguration = true
                    }
                    .accessibilityIdentifier("budget-setup")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Income", systemImage: "arrow.triangle.2.circlepath") {
                        isShowingRecurringIncome = true
                    }
                    .accessibilityIdentifier("budget-income-rules")
                }
            }
            .appSheet(isPresented: $isShowingRecurringIncome) {
                RecurringListView(asOf: asOf)
            }
            .appSheet(isPresented: $isShowingConfiguration) {
                BudgetConfigurationView()
            }
            .appSheet(isPresented: $isShowingGoals) {
                GoalListView(plannedByJar: plannedByJar, asOf: asOf)
            }
            .appSheet(isPresented: $isShowingIncomeTimeline) {
                IncomeAllocationTimelineView(asOf: asOf)
            }
            .navigationDestination(item: $selectedJarID) { jarID in
                if let row = snapshot.rows.first(where: { $0.jarID == jarID }) {
                    BudgetJarDetailView(row: row, month: visibleMonth, asOf: asOf)
                }
            }
            .navigationDestination(item: $selectedGoalID) { goalID in
                GoalDetailView(goalID: goalID, plannedByJar: plannedByJar, asOf: asOf)
            }
            .alert(
                "Couldn’t start this trip",
                isPresented: startErrorBinding,
                presenting: startErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var snapshot: BudgetSnapshot {
        BudgetSummary.snapshot(
            monthContaining: visibleMonth,
            asOf: asOf,
            jars: jars,
            categories: categories,
            recurringRules: recurringRules,
            transactions: transactions,
            savingsDeposits: savingsDeposits,
            fundHoldings: fundHoldings
        )
    }

    private var monthTitle: String {
        TransactionPeriod.title(for: visibleMonth, in: locale)
    }

    private var visibleMonth: Date {
        selectedMonth ?? TransactionPeriod.startOfMonth(for: asOf)
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

    private var plannedByJar: [UUID: Decimal] {
        Dictionary(uniqueKeysWithValues: snapshot.rows.map { ($0.jarID, $0.planned) })
    }

    private var inProgressGoals: [FinancialGoal] {
        goals.filter { $0.earmarkedAmount < $0.targetAmount }
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
                            + tripCollection.readyGoals.count
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

            if inProgressGoals.isEmpty && tripCollection.readyGoals.isEmpty && activeTrips.isEmpty {
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
                readyTripList
                activeTripList
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("budget-goal-overview")
    }

    @ViewBuilder
    private var readyTripList: some View {
        if !tripCollection.readyGoals.isEmpty {
            Text("Ready to spend")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            ForEach(tripCollection.readyGoals) { goal in
                TripReadyCard(
                    goal: goal,
                    jarName: goal.fundingJarID.flatMap(jarName)
                        ?? String(localized: "No jar"),
                    onStart: { startSpending(goal) }
                )
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
                Button {
                    selectedGoalID = goal.id
                } label: {
                    GoalCard(
                        goal: goal,
                        jarName: goal.fundingJarID.flatMap(jarName)
                            ?? String(localized: "No jar"),
                        asOf: asOf
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this goal's details")
                .accessibilityIdentifier("budget-goal-\(goal.id.uuidString)")
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
                    isShowingGoals = true
                } label: {
                    TripWorkspaceCard(
                        workspace: workspace,
                        snapshot: TripSummary.snapshot(
                            workspace: workspace,
                            transactions: transactions,
                            categories: categories
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens all goals")
                .accessibilityIdentifier("budget-active-trip-\(workspace.id.uuidString)")
            }
        }
    }

    private func jarName(_ id: UUID) -> String? {
        jars.first { $0.id == id }?.name
    }

    private var startErrorBinding: Binding<Bool> {
        Binding(
            get: { startErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    startErrorMessage = nil
                }
            }
        )
    }

    private func startSpending(_ goal: FinancialGoal) {
        startErrorMessage = nil
        do {
            try TripWorkspaceLifecycle.start(
                goal: goal,
                existingWorkspaces: tripWorkspaces,
                id: UUID(),
                startedAt: .now,
                in: modelContext
            )
        } catch TripWorkspaceLifecycleError.workspaceAlreadyExists {
            startErrorMessage = "This goal already has a trip workspace."
        } catch {
            startErrorMessage = "Check that this Trip goal is fully funded and has a funding jar."
        }
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

#if DEBUG
    #Preview("Budget") {
        let container = PreviewData.populated
        BudgetJarSeed.seedIfNeeded(
            in: container.mainContext,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            locale: Locale(identifier: "en")
        )
        return BudgetScreen(asOf: Date(timeIntervalSince1970: 1_700_000_000))
            .modelContainer(container)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
