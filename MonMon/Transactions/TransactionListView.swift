import SwiftData
import SwiftUI

struct TransactionListView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var range = TransactionRange.month(containing: .now)
    @State private var editorMode: TransactionEditorMode?
    @State private var breakdownKind: TransactionKind = .expense
    @State private var isManagingCategories = false
    @State private var isManagingRecurring = false
    @State private var isEditingDefaults = false
    @State private var listFilter = TransactionListFilter.all

    /// Weekday first: over a run of days the name is what the eye picks out,
    /// and the year is left to the period title above the list.
    private static let dayTemplate = Date.FormatStyle().weekday(.abbreviated).day().month(
        .abbreviated)

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        SpendingOverviewCard(
                            title: range.title(in: locale),
                            income: income,
                            expense: expense,
                            count: visibleTransactions.count
                        )

                        if accounts.isEmpty {
                            noAccountState
                        } else {
                            quickActions

                            CategoryBreakdownCard(
                                kind: $breakdownKind,
                                slices: breakdownSlices,
                                range: range
                            )

                            TransactionCalendarCard(
                                month: calendarMonth,
                                weeks: calendarWeeks,
                                onStepMonth: stepCalendarMonth
                            )

                            if !visibleTransactions.isEmpty {
                                transactionsSection
                            }
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, FloatingAddButton.contentInset)
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !accounts.isEmpty {
                    FloatingAddButton(
                        title: "Add Transaction",
                        accessibilityIdentifier: "add-transaction"
                    ) {
                        editorMode = .add
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                monthRail
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DateRangeFilterButton(range: $range, systemImage: "calendar")
                }
            }
            .navigationDestination(for: CategoryPeriod.self) { period in
                CategoryTransactionsView(period: period)
            }
            .navigationDestination(for: DayPeriod.self) { period in
                DayTransactionsView(period: period)
            }
            .compactRootNavigationTitle("Spending")
            .accessibilityIdentifier("spending-list")
            .sheet(item: $editorMode) { mode in
                TransactionEditorView(mode: mode, defaultDate: defaultDate)
            }
            .sheet(isPresented: $isManagingCategories) {
                CategoryListView()
            }
            .sheet(isPresented: $isManagingRecurring) {
                RecurringListView()
            }
            .sheet(isPresented: $isEditingDefaults) {
                TransactionDefaultsView()
            }
            .tint(MonMonTheme.accent)
        }
    }

    /// Adding from a period that does not include today starts on its first
    /// day, so the new entry lands where the owner is looking.
    private var defaultDate: Date {
        range.contains(.now) ? .now : range.start
    }

    /// The month the calendar draws. It follows the period on show rather than
    /// keeping a month of its own, so the grid and the totals above it can never
    /// disagree about where the owner is looking.
    private var calendarMonth: Date {
        TransactionPeriod.startOfMonth(for: range.start)
    }

    /// Built from every transaction, not the ones in range: the grid covers a
    /// whole month even when the period narrows to a single day inside it.
    private var calendarWeeks: [TransactionCalendarWeek] {
        TransactionCalendar.weeks(of: calendarMonth, transactions: transactions)
    }

    /// Stepping the calendar is how an owner says "show me that month", so it
    /// re-cuts the period to the month it lands on rather than leaving the
    /// figures above describing the month they stepped away from.
    private func stepCalendarMonth(_ steps: Int) {
        let calendar = TransactionPeriod.calendar

        guard let moved = calendar.date(byAdding: .month, value: steps, to: calendarMonth) else {
            return
        }

        range = .month(containing: moved)
    }

    private var visibleTransactions: [MoneyTransaction] {
        TransactionSummary.inRange(range, transactions: transactions)
    }

    private var breakdownSlices: [CategoryBreakdownSlice] {
        CategoryBreakdown.slices(
            of: breakdownKind,
            transactions: visibleTransactions,
            categories: categories
        )
    }

    /// The three things the owner sets up rather than records: what a
    /// transaction can be filed under, what records itself, and what a new one
    /// starts on. They sit above the breakdown because each one changes what it
    /// shows, and none of them belongs on the floating add button.
    private var quickActions: some View {
        // Three labelled buttons crowd an iPhone in one row, so the labels drop
        // below the icons before the row wraps.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                quickActionButtons(isStacked: false)
            }

            HStack(spacing: 10) {
                quickActionButtons(isStacked: true)
            }
        }
    }

    @ViewBuilder
    private func quickActionButtons(isStacked: Bool) -> some View {
        quickAction(
            "Categories",
            systemImage: "tag.fill",
            isStacked: isStacked,
            accessibilityIdentifier: "manage-categories"
        ) {
            isManagingCategories = true
        }

        quickAction(
            "Recurring",
            systemImage: "arrow.triangle.2.circlepath",
            isStacked: isStacked,
            accessibilityIdentifier: "manage-recurring"
        ) {
            isManagingRecurring = true
        }

        quickAction(
            "Defaults",
            systemImage: "slider.horizontal.3",
            isStacked: isStacked,
            accessibilityIdentifier: "manage-transaction-defaults"
        ) {
            isEditingDefaults = true
        }
    }

    private func quickAction(
        _ title: String,
        systemImage: String,
        isStacked: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isStacked {
                    VStack(spacing: 6) {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))

                        Text(title)
                            .font(.caption.weight(.semibold))
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))

                        Text(title)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .lineLimit(1)
            .foregroundStyle(MonMonTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// The months either side of the one on show, pinned under the navigation
    /// bar so a month is one tap away wherever the screen is scrolled to.
    private var monthRail: some View {
        MonthRail(months: railMonths, selection: calendarMonth) { month in
            range = .month(containing: month)
        }
        .background(MonMonTheme.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonMonTheme.border)
                .frame(height: 1)
        }
    }

    /// The rail spans the years the calendars offer, widened when the period on
    /// show sits outside them, so the month being looked at is always on it.
    private var railMonths: [Date] {
        TransactionPeriod.months(
            from: min(CalendarTheme.startMonth(), calendarMonth),
            through: max(CalendarTheme.endMonth(), calendarMonth)
        )
    }

    private var income: Decimal {
        TransactionSummary.totalIncome(of: visibleTransactions)
    }

    private var expense: Decimal {
        TransactionSummary.totalExpense(of: visibleTransactions)
    }

    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    /// Transactions run in date order, so the list breaks them at each day and
    /// heads the run with that date and what the day came to. The cards below a
    /// header drop their own date, which the header now carries.
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Text("Transactions")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                // Narrows the list only. The card above still counts both
                // directions, which is what the period is judged on.
                Picker("Show", selection: $listFilter) {
                    ForEach(TransactionListFilter.allCases) { filter in
                        Text(filter.displayName)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 210)
                .accessibilityIdentifier("transaction-filter")
            }

            if filteredTransactions.isEmpty {
                Text(emptyFilterNotice)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            ForEach(dayGroups) { group in
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
                        .accessibilityIdentifier("transaction-\(transaction.id.uuidString)")
                        .accessibilityHint("Opens the transaction editor.")
                    }
                }
            }
        }
    }

    private var filteredTransactions: [MoneyTransaction] {
        TransactionSummary.matching(listFilter, transactions: visibleTransactions)
    }

    private var dayGroups: [TransactionDayGroup] {
        TransactionSummary.byDay(filteredTransactions)
    }

    private var emptyFilterNotice: LocalizedStringKey {
        guard let kind = listFilter.kind else {
            return "Nothing recorded \(range.phrase(in: locale))."
        }

        return
            "No \(kind.displayName(in: locale).lowercased()) recorded \(range.phrase(in: locale))."
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
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(MonMonTheme.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
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

    private var noAccountState: some View {
        placeholder(
            symbolName: "wallet.bifold.fill",
            title: "Add an account first",
            message: "Every transaction moves one account, so there has to be one to move."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        symbolName: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            action()
                .buttonStyle(.prominentAction)
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
    }
}
