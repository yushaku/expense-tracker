import SwiftData
import SwiftUI

/// Where the ledger is looked back over rather than added to: search words, a
/// period, filters, the charts that answer them, and the transactions behind
/// every figure.
///
/// The Spending screen is for recording today. This screen is for the question
/// that comes later — where did it go — so one query drives the charts and the
/// list together and the two can never describe different transactions.
struct ReportView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    /// A year, not a month: the charts here are about a run of months, and a
    /// period narrower than one bar has nothing to trend.
    @State private var query = TransactionQuery(range: .year(containing: .now))
    @State private var breakdownKind: TransactionKind = .expense
    @State private var editorMode: TransactionEditorMode?
    @State private var isSearching = false
    @State private var isFiltering = false

    /// Weekday first: over a run of days the name is what the eye picks out, and
    /// the year is left to the period title above the list.
    private static let dayTemplate = Date.FormatStyle().weekday(.abbreviated).day().month(
        .abbreviated)

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                content
                    .onMonthSwipe(perform: stepReportMonth)
            }
            .compactRootNavigationTitle("Report")
            .accessibilityIdentifier("report")
            .searchable(
                text: $query.text,
                isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("Search notes, categories, amounts")
            )
            .safeAreaInset(edge: .top, spacing: 0) {
                monthRail
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    searchButton

                    filterButton

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
            .sheet(isPresented: $isFiltering) {
                ReportFilterSheet(
                    query: $query,
                    categories: categories,
                    accounts: accounts
                )
            }
            .sheet(item: $editorMode) { mode in
                TransactionEditorView(mode: mode, defaultDate: defaultDate)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var content: some View {
        // Every card below reads the same results, so they are worked out once
        // here rather than once per card.
        let results = self.results

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                if !query.hasSearchText {
                    SpendingOverviewCard(
                        title: query.range.title(in: locale),
                        income: TransactionSummary.totalIncome(of: results),
                        expense: TransactionSummary.totalExpense(of: results),
                        count: results.count
                    )
                }

                if query.isNarrowed {
                    activeFilters
                }

                if results.isEmpty {
                    emptyState
                } else {
                    if !query.hasSearchText {
                        MonthlyFlowCard(months: TransactionSummary.byMonth(results))

                        NetTrendCard(points: TransactionSummary.runningNet(results))
                    }

                    CategoryBreakdownCard(
                        kind: $breakdownKind,
                        slices: breakdownSlices(of: results),
                        range: query.range
                    )

                    resultsSection(results)
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

    /// The months either side of the report period, pinned under the navigation
    /// bar so moving from a wider report to one month takes a single tap.
    private var monthRail: some View {
        MonthRail(months: railMonths, selection: reportMonth) { month in
            query.range = .month(containing: month)
        }
        .background(MonMonTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonMonTheme.border)
                .frame(height: 1)
        }
    }

    /// A wider period is represented by its first month, matching the Spending
    /// screen when its date filter is set to a year or a custom range.
    private var reportMonth: Date {
        TransactionPeriod.startOfMonth(for: query.range.start)
    }

    private func stepReportMonth(_ steps: Int) {
        guard
            let moved = TransactionPeriod.calendar.date(
                byAdding: .month,
                value: steps,
                to: reportMonth
            )
        else {
            return
        }

        query.range = .month(containing: moved)
    }

    /// Keep the selected month on the rail even when a custom range lies beyond
    /// the calendar picker's ordinary bounds.
    private var railMonths: [Date] {
        TransactionPeriod.months(
            from: min(CalendarTheme.startMonth(), reportMonth),
            through: max(CalendarTheme.endMonth(), reportMonth)
        )
    }

    private var searchButton: some View {
        Button {
            isSearching = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(MonMonTheme.accent.opacity(0.16), in: Circle())

                if query.hasSearchText {
                    Circle()
                        .fill(MonMonTheme.accent)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search transactions")
        .accessibilityIdentifier("open-report-search")
    }

    private var filterButton: some View {
        Button {
            isFiltering = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(MonMonTheme.accent.opacity(0.16), in: Circle())

                // A filter left on from an earlier question is the easiest thing
                // on this screen to forget, so the button says when one is.
                if query.hasStructuredFilters {
                    Circle()
                        .fill(MonMonTheme.accent)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
        .accessibilityIdentifier("open-report-filters")
    }

    /// What is narrowing the results, each one removable where it is read.
    private var activeFilters: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                filterChips
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChips
                }
            }
        }
    }

    @ViewBuilder
    private var filterChips: some View {
        if !query.trimmedText.isEmpty {
            chip(query.trimmedText, systemImage: "magnifyingglass") {
                query.text = ""
            }
        }

        if query.filter != .all {
            chip(
                AppText.string(key: filterName, in: locale),
                systemImage: "arrow.left.arrow.right"
            ) {
                query.filter = .all
            }
        }

        ForEach(selectedCategories) { category in
            chip(category.name, systemImage: CategoryPalette.symbolName(category.symbolName)) {
                query.categoryIDs.remove(category.id)
            }
        }

        ForEach(selectedAccounts) { account in
            chip(account.name, systemImage: account.kind.iconName) {
                query.accountIDs.remove(account.id)
            }
        }

        Spacer(minLength: 0)
    }

    private var filterName: String {
        query.filter.kind?.nameKey ?? "All"
    }

    private var selectedCategories: [TransactionCategory] {
        categories.filter { query.categoryIDs.contains($0.id) }
    }

    private var selectedAccounts: [CashAccount] {
        accounts.filter { query.accountIDs.contains($0.id) }
    }

    private func chip(
        _ title: String,
        systemImage: String,
        onRemove: @escaping () -> Void
    ) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(MonMonTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(title)")
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

    /// The transactions behind every figure above, broken at each day the way
    /// the Spending screen breaks them, so a result read here reads the same as
    /// it does where it was recorded.
    private func resultsSection(_ results: [MoneyTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text("Results")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(results.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer(minLength: 8)
            }

            ForEach(TransactionSummary.byDay(results)) { group in
                VStack(alignment: .leading, spacing: 12) {
                    dayHeader(for: group)

                    ForEach(group.transactions) { transaction in
                        Button {
                            editorMode = .edit(transaction)
                        } label: {
                            TransactionCard(
                                transaction: transaction,
                                category: category(for: transaction),
                                account: account(for: transaction),
                                showsDate: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("report-transaction-\(transaction.id.uuidString)")
                        .accessibilityHint("Opens the transaction editor.")
                    }
                }
            }
        }
    }

    private func dayHeader(for group: TransactionDayGroup) -> some View {
        HStack(spacing: 12) {
            Text(
                TransactionPeriod.format(Self.dayTemplate, in: locale).format(group.day)
                    .uppercased()
            )
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(signed(group.net))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(group.net < 0 ? MonMonTheme.danger : MonMonTheme.gain)
        }
        .foregroundStyle(MonMonTheme.textSecondary)
        .accessibilityElement(children: .combine)
    }

    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        guard let categoryID = transaction.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private func account(for transaction: MoneyTransaction) -> CashAccount? {
        accounts.first { $0.id == transaction.accountID }
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
