import SwiftData
import SwiftUI

private enum SpendingDestination: Hashable {
    case accounts
}

struct TransactionListView: View {
    @Environment(AppRoute.self) private var appRoute
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \PendingTransactionCapture.createdAt, order: .reverse)
    private var pendingCaptures: [PendingTransactionCapture]

    @State private var query = TransactionQuery(range: .month(containing: .now))
    @State private var editorMode: TransactionEditorMode?
    @State private var isManagingCategories = false
    @State private var isManagingRecurring = false
    @State private var isEditingDefaults = false
    @State private var isFiltering = false
    @State private var transactionActions = TransactionActions()
    @State private var importInbox = StatementImportInbox.live()
    @State private var isShowingImportInbox = false
    @State private var navigationPath = NavigationPath()

    @State private var isShowingCaptureInbox = false
    @State private var isShowingQuickCapture = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        if !pendingCaptures.isEmpty {
                            pendingCaptureStatusCard
                        }

                        if showsImportStatus {
                            importStatusCard
                        }

                        if query.isNarrowed {
                            TransactionFilterChips(
                                query: $query,
                                categories: categories,
                                accounts: accounts
                            )
                        }

                        if accounts.isEmpty {
                            noAccountState
                        } else {
                            quickActions

                            transactionsSection
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
                ToolbarItemGroup(placement: .primaryAction) {
                    importInboxButton

                    TransactionSearchButton(
                        isActive: query.hasSearchText,
                        accessibilityIdentifier: "open-spending-search"
                    ) {
                        isFiltering = true
                    }

                    DateRangeFilterButton(range: $query.range, systemImage: "calendar")
                }
            }
            .navigationDestination(for: DayPeriod.self) { period in
                DayTransactionsView(period: period)
            }
            .navigationDestination(for: SpendingDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsScreen()
                }
            }
            .navigationDestination(for: AccountDetailRoute.self) { route in
                AccountDetailView(route: route)
            }
            .compactRootNavigationTitle("Spending")
            .accessibilityIdentifier("spending-list")
            .appSheet(item: $editorMode) { mode in
                TransactionEditorView(mode: mode, defaultDate: defaultDate)
            }
            .appSheet(isPresented: $isFiltering) {
                ReportFilterSheet(
                    query: $query,
                    categories: categories,
                    accounts: accounts,
                    focusesSearchOnAppear: true,
                    identifierPrefix: "spending-"
                )
            }
            .appSheet(isPresented: $isManagingCategories) {
                CategoryListView()
            }
            .appSheet(isPresented: $isManagingRecurring) {
                RecurringListView()
            }
            .appSheet(isPresented: $isEditingDefaults) {
                TransactionDefaultsView()
            }
            .appSheet(isPresented: $isShowingImportInbox) {
                StatementImportInboxView(inbox: importInbox)
            }
            .appSheet(isPresented: $isShowingCaptureInbox) {
                PendingTransactionCaptureListView()
            }
            .appSheet(isPresented: $isShowingQuickCapture) {
                QuickTransactionCaptureView()
            }
            .transactionActions(
                transactionActions,
                undoBottomInset: FloatingAddButton.contentInset,
                category: category(for:),
                account: account(for:),
                onEdit: { editorMode = .edit($0) }
            )
            .task { await importInbox.refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else {
                    return
                }
                Task { await importInbox.refresh() }
            }
            .onChange(of: appRoute.quickCaptureRequestID) { _, requestID in
                presentQuickCaptureIfNeeded(requestID)
            }
            .onAppear {
                presentQuickCaptureIfNeeded(appRoute.quickCaptureRequestID)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private func presentQuickCaptureIfNeeded(_ requestID: UUID?) {
        guard requestID != nil, !isShowingQuickCapture else {
            return
        }
        isShowingQuickCapture = true
        appRoute.consumeQuickCapture()
    }

    private var pendingCaptureStatusCard: some View {
        Button {
            isShowingCaptureInbox = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(MonMonTheme.credit)
                    .frame(width: 44, height: 44)
                    .background(
                        MonMonTheme.credit.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(pendingCaptureTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)

                    Text("Finish the details before these entries affect your totals.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MonMonTheme.credit.opacity(0.5), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture-inbox-status")
    }

    private var pendingCaptureTitle: LocalizedStringKey {
        pendingCaptures.count == 1
            ? "1 spoken transaction needs review"
            : "\(pendingCaptures.count) spoken transactions need review"
    }

    private var showsImportStatus: Bool {
        if case .failed = importInbox.listPhase {
            return true
        }
        return (importInbox.pendingCount ?? 0) > 0
    }

    private var importInboxButton: some View {
        Button {
            isShowingImportInbox = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: hasPendingImports ? "tray.full" : "tray")

                if let count = importInbox.pendingCount, count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(MonMonTheme.onAccent)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 13, minHeight: 13)
                        .background(MonMonTheme.danger, in: Capsule())
                        .offset(x: 8, y: -7)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 32, height: 32)
        }
        .accessibilityLabel(importInboxAccessibilityLabel)
        .accessibilityIdentifier("open-import-inbox")
    }

    private var importInboxAccessibilityLabel: String {
        switch importInbox.listPhase {
        case .failed:
            AppText.string("Import Inbox needs attention", in: locale)
        case .loaded(let statements) where statements.count == 1:
            AppText.string("Import Inbox, 1 statement waiting", in: locale)
        case .loaded(let statements):
            AppText.string("Import Inbox, \(statements.count) statements waiting", in: locale)
        case .idle, .loading:
            AppText.string("Import Inbox, checking for statements", in: locale)
        }
    }

    private var hasPendingImports: Bool {
        (importInbox.pendingCount ?? 0) > 0
    }

    private var importStatusCard: some View {
        Button {
            isShowingImportInbox = true
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName: importStatusIsFailure
                        ? "exclamationmark.triangle.fill" : "tray.full.fill"
                )
                .font(.title3)
                .foregroundStyle(importStatusIsFailure ? MonMonTheme.danger : MonMonTheme.bank)
                .frame(width: 44, height: 44)
                .background(
                    (importStatusIsFailure ? MonMonTheme.danger : MonMonTheme.bank).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(importStatusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)

                    Text(importStatusMessage)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        importStatusIsFailure
                            ? MonMonTheme.danger.opacity(0.5) : MonMonTheme.border,
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("import-inbox-status")
    }

    private var importStatusIsFailure: Bool {
        if case .failed = importInbox.listPhase {
            return true
        }
        return false
    }

    private var importStatusTitle: LocalizedStringKey {
        if importStatusIsFailure {
            return "Import Inbox needs attention"
        }
        if importInbox.pendingCount == 1 {
            return "1 statement waiting for review"
        }
        return "\(importInbox.pendingCount ?? 0) statements waiting for review"
    }

    private var importStatusMessage: LocalizedStringKey {
        if importStatusIsFailure {
            return "MonMon could not check the shared inbox. Open it to try again."
        }
        return "Review the bank statement locally. Nothing has been added yet."
    }

    /// Adding from a period that does not include today starts on its first
    /// day, so the new entry lands where the owner is looking.
    private var defaultDate: Date {
        query.range.contains(.now) ? .now : query.range.start
    }

    /// The month represented by the rail. It follows the period on show rather
    /// than keeping a month of its own.
    private var selectedMonth: Date {
        TransactionPeriod.startOfMonth(for: query.range.start)
    }

    private var visibleTransactions: [MoneyTransaction] {
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

    /// The three things the owner sets up rather than records: what a
    /// transaction can be filed under, what records itself, and what a new one
    /// starts on. They sit above the transactions, and none of them belongs on
    /// the floating add button.
    private var quickActions: some View {
        // Four labelled buttons crowd an iPhone in one row, so the labels drop
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

        // The one that pushes rather than opening a sheet: accounts are a screen
        // of their own, and reaching them from the Wealth tab is two taps from
        // where the money is being recorded.
        quickAction(
            "Accounts",
            systemImage: "wallet.bifold.fill",
            isStacked: isStacked,
            accessibilityIdentifier: "open-accounts"
        ) {
            navigationPath.append(SpendingDestination.accounts)
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
        MonthRail(months: railMonths, selection: selectedMonth) { month in
            query.range = .month(containing: month)
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
            from: min(CalendarTheme.startMonth(), selectedMonth),
            through: max(CalendarTheme.endMonth(), selectedMonth)
        )
    }

    private var transactionsSection: some View {
        TransactionListSection(
            title: "Transactions",
            transactions: visibleTransactions,
            categories: categories,
            accounts: accounts,
            emptyNotice: emptyFilterNotice
        ) {
            // This affects the rows only. The period-wide figures live on
            // Report and continue to count both directions.
            Picker("Show", selection: $query.filter) {
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

    private var emptyFilterNotice: LocalizedStringKey {
        query.isNarrowed
            ? "Nothing matches what you are looking for."
            : "Nothing recorded \(query.range.phrase(in: locale))."
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
