import SwiftData
import SwiftUI

/// Where the ledger is looked back over rather than added to: search words, a
/// period, filters, the figures that answer them, and search results when words
/// have been entered.
///
/// The Spending screen is for recording today. This screen is for the question
/// that comes later — where did it go — so one query drives the charts and the
/// search results together and the two can never describe different
/// transactions.
struct ReportContentVisibility: Equatable {
    let showsNetTrend: Bool
    let showsTransactionList: Bool

    init(query: TransactionQuery) {
        showsNetTrend = !query.hasSearchText
        showsTransactionList = query.hasSearchText
    }
}

struct ReportView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var summaryMonth = TransactionPeriod.startOfMonth(for: .now)

    /// A year, not a month: the charts here are about a run of months, and a
    /// period narrower than one bar has nothing to trend.
    @State private var query = TransactionQuery(range: .year(containing: .now))
    @State private var breakdownKind: TransactionKind = .expense
    @State private var editorMode: TransactionEditorMode?
    @State private var isFiltering = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                content
            }
            .compactRootNavigationTitle("Report")
            .accessibilityIdentifier("report")
            .safeAreaInset(edge: .top, spacing: 0) {
                monthRail
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    TransactionSearchButton(
                        isActive: query.hasSearchText,
                        accessibilityIdentifier: "open-report-search"
                    ) {
                        isFiltering = true
                    }

                    DateRangeFilterButton(
                        range: $query.range,
                        identifierPrefix: "report-",
                        systemImage: "calendar"
                    )
                }
            }
            .navigationDestination(for: CategoryPeriod.self) { period in
                CategoryTransactionsView(period: period)
            }
            .navigationDestination(for: DayPeriod.self) { period in
                DayTransactionsView(period: period)
            }
            .navigationDestination(for: AccountActivityRoute.self) { route in
                if let account = account(route.accountID) {
                    AccountActivityView(account: account)
                }
            }
            .appSheet(isPresented: $isFiltering) {
                ReportFilterSheet(
                    query: $query,
                    categories: categories,
                    accounts: accounts,
                    focusesSearchOnAppear: true
                )
            }
            .appSheet(item: $editorMode) { mode in
                TransactionEditorView(mode: mode, defaultDate: defaultDate)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var content: some View {
        // Every card below reads the same results, so they are worked out once
        // here rather than once per card.
        let results = self.results
        let summaryTransactions = self.summaryTransactions
        let visibility = ReportContentVisibility(query: query)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                if query.isNarrowed {
                    TransactionFilterChips(
                        query: $query,
                        categories: categories,
                        accounts: accounts
                    )
                }

                SpendingOverviewCard(
                    title: summaryRange.title(in: locale),
                    income: TransactionSummary.totalIncome(of: summaryTransactions),
                    expense: TransactionSummary.totalExpense(of: summaryTransactions),
                    count: summaryTransactions.count
                )
                .accessibilityIdentifier("report-overview")

                TransactionCalendarCard(
                    month: summaryMonth,
                    weeks: summaryCalendarWeeks,
                    onStepMonth: stepSummaryMonth
                )

                AccountSpendingSection(
                    monthTitle: summaryRange.title(in: locale),
                    rows: AccountSpendingSummary.rows(
                        accounts: accounts,
                        transactions: summaryTransactions
                    ),
                    accounts: accounts
                )

                if results.isEmpty {
                    emptyState
                } else {
                    CategoryBreakdownCard(
                        kind: $breakdownKind,
                        slices: breakdownSlices(of: results),
                        range: query.range
                    )

                    if visibility.showsTransactionList {
                        resultsSection(results)
                    }

                    if visibility.showsNetTrend {
                        NetTrendCard(points: TransactionSummary.runningNet(results))
                    }
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }

    private var results: [MoneyTransaction] {
        TransactionSearch.results(
            of: query,
            transactions: transactions,
            categoryNames: categoryNames,
            accountNames: accountNames
        )
    }

    private var summaryRange: TransactionRange {
        .month(containing: summaryMonth)
    }

    private var summaryTransactions: [MoneyTransaction] {
        TransactionSummary.inRange(summaryRange, transactions: transactions)
    }

    private var summaryCalendarWeeks: [TransactionCalendarWeek] {
        TransactionCalendar.weeks(
            of: summaryMonth,
            transactions: transactions
        )
    }

    private func stepSummaryMonth(_ steps: Int) {
        let calendar = TransactionPeriod.calendar

        guard let moved = calendar.date(byAdding: .month, value: steps, to: summaryMonth) else {
            return
        }

        summaryMonth = TransactionPeriod.startOfMonth(for: moved)
    }

    private var categoryNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    }

    private var accountNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })
    }

    private func breakdownSlices(of results: [MoneyTransaction]) -> [CategoryBreakdownSlice] {
        CategoryBreakdown.slices(
            of: breakdownKind,
            transactions: results,
            categories: categories
        )
    }

    /// Editing from a period that does not include today starts on its first
    /// day, so a new entry lands where the owner is looking.
    private var defaultDate: Date {
        query.range.contains(.now) ? .now : query.range.start
    }

    /// The month summarized by the overview and account spending, kept separate
    /// from the wider query that drives charts and search.
    private var monthRail: some View {
        MonthRail(months: railMonths, selection: summaryMonth) { month in
            summaryMonth = TransactionPeriod.startOfMonth(for: month)
        }
        .background(MonMonTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonMonTheme.border)
                .frame(height: 1)
        }
    }

    /// Keep the selected summary month on the rail even when it lies beyond the
    /// calendar picker's ordinary bounds.
    private var railMonths: [Date] {
        TransactionPeriod.months(
            from: min(CalendarTheme.startMonth(), summaryMonth),
            through: max(CalendarTheme.endMonth(), summaryMonth)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 56, height: 56)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text(emptyNotice)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("report-empty")
    }

    private var emptyNotice: LocalizedStringKey {
        query.isNarrowed
            ? "Nothing matches what you are looking for."
            : "Nothing recorded \(query.range.phrase(in: locale))."
    }

    private func resultsSection(_ results: [MoneyTransaction]) -> some View {
        TransactionListSection(
            title: "Results",
            transactions: results,
            categories: categories,
            accounts: accounts,
            emptyNotice: "Nothing matches what you are looking for.",
            accessibilityIdentifierPrefix: "report-transaction",
            showsCount: true,
            onEdit: { transaction in
                editorMode = .edit(transaction)
            }
        )
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }
}

#if DEBUG
    #Preview("Report") {
        ReportView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
