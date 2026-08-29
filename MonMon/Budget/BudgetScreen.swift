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

    private let asOf: Date

    init(asOf: Date = .now) {
        self.asOf = asOf
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        BudgetIncomeCard(snapshot: snapshot, monthTitle: monthTitle)

                        if snapshot.plannedIncome == 0 && snapshot.receivedIncome == 0 {
                            noIncomeCard
                        }

                        ForEach(snapshot.rows) { row in
                            BudgetJarCard(row: row)
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .compactRootNavigationTitle("Budget")
            .accessibilityIdentifier("budget")
            .toolbar {
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
            .tint(MonMonTheme.accent)
        }
    }

    private var snapshot: BudgetSnapshot {
        BudgetSummary.snapshot(
            monthContaining: asOf,
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
        TransactionPeriod.title(for: asOf, in: locale)
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
