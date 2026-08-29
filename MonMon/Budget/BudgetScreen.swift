import SwiftData
import SwiftUI

struct BudgetScreen: View {
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

    @State private var isShowingRecurringIncome = false
    @State private var isShowingConfiguration = false
    @State private var isShowingGoals = false
    @State private var isShowingIncomeTimeline = false
    @State private var selectedJarID: UUID?
    @State private var selectedMonth: Date?

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
                    Button("Goals", systemImage: "flag.checkered") {
                        isShowingGoals = true
                    }
                    .accessibilityIdentifier("budget-goals")
                }

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
