import SwiftData
import SwiftUI

struct AccountDetailRoute: Hashable {
    let accountID: UUID
}

private enum AccountDetailTab: CaseIterable, Hashable {
    case transactions
    case linkedInvestments

    var title: LocalizedStringKey {
        switch self {
        case .transactions: "Transactions"
        case .linkedInvestments: "Linked Investments"
        }
    }
}

struct AccountDetailView: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.dismiss) private var dismiss

    @Environment(\.locale) private var locale

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    /// This account's transactions only, all time: the balance needs every
    /// one of them, the history and trend only the selected period.
    @Query private var transactions: [MoneyTransaction]

    /// Transfers with this account at either end.
    @Query private var transfers: [AccountTransfer]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    /// Payments made from or into this account. The debts stay unfiltered:
    /// a payment takes its direction from its debt, which may have been
    /// opened against another account.
    @Query private var payments: [DebtPayment]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    let route: AccountDetailRoute

    @State private var accountEditorMode: AccountEditorMode?
    @State private var transactionEditorMode: TransactionEditorMode?
    @State private var transactionActions = TransactionActions()
    @State private var selectedRange = TransactionRange.month(containing: .now)

    init(route: AccountDetailRoute) {
        self.route = route
        let accountID = route.accountID
        _transactions = Query(LedgerFetch.transactions(inAccount: accountID))
        _transfers = Query(LedgerFetch.transfers(touching: accountID))
        _payments = Query(
            FetchDescriptor<DebtPayment>(
                predicate: #Predicate { $0.accountID == accountID },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        )
    }

    private var account: CashAccount? {
        accounts.first { $0.id == route.accountID }
    }

    var body: some View {
        let lookup = Lookup(categories: categories, accounts: accounts)

        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            if let account {
                content(for: account)
            }
        }
        .navigationTitle(account?.name ?? "Account")
        .accessibilityIdentifier("account-detail")
        .toolbar {
            if let account {
                ToolbarItemGroup(placement: .primaryAction) {
                    DateRangeFilterButton(
                        range: $selectedRange,
                        identifierPrefix: "account-detail",
                        systemImage: "calendar"
                    )

                    Button("Edit", systemImage: "pencil") {
                        accountEditorMode = .edit(account)
                    }
                    .accessibilityIdentifier("account-detail-edit")
                }
            }
        }
        .appSheet(item: $accountEditorMode) { mode in
            AccountEditorView(mode: mode)
        }
        .appSheet(item: $transactionEditorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .transactionActions(
            transactionActions,
            category: lookup.category(for:),
            account: lookup.account(for:),
            onEdit: { transactionEditorMode = .edit($0) }
        )
        .tint(MonMonTheme.accent)
        // Deleting the account this screen is about leaves nothing here to
        // show, so the screen goes with it rather than staying as an empty
        // page under the account's old name.
        .onChange(of: account?.id) { _, id in
            if id == nil {
                dismiss()
            }
        }
    }

    private func content(for account: CashAccount) -> some View {
        // Both queries are already cut to this account, so the balance reads
        // them as they are and the period's activity is filtered once and
        // shared by the trend and the history.
        let availableBalance = CashBalanceSummary.available(
            for: account,
            deposits: deposits,
            holdings: holdings,
            withdrawals: withdrawals,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
        let accountTransactions = transactions.filter { selectedRange.contains($0.occurredAt) }
        let accountTransfers = transfers.filter { selectedRange.contains($0.occurredAt) }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                CashAccountCard(
                    account: account,
                    availableBalance: availableBalance,
                    deposits: deposits,
                    withdrawals: withdrawals,
                    holdings: holdings,
                    sales: sales
                )

                AccountActivityTabs(
                    accountID: account.id,
                    transactions: accountTransactions,
                    transfers: accountTransfers,
                    range: selectedRange,
                    emptyNotice: emptyTransactionNotice,
                    categories: categories,
                    accounts: accounts,
                    deposits: deposits,
                    withdrawals: withdrawals,
                    holdings: holdings,
                    sales: sales,
                    instruments: instruments
                )
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyTransactionNotice: LocalizedStringKey {
        "No transactions recorded \(selectedRange.phrase(in: locale, dateFormat: dateFormat))."
    }

    /// Category and account by id, built once per update instead of a linear
    /// search per row action.
    private struct Lookup {
        let categoriesByID: [UUID: TransactionCategory]
        let accountsByID: [UUID: CashAccount]

        init(categories: [TransactionCategory], accounts: [CashAccount]) {
            categoriesByID = Dictionary(
                categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            accountsByID = Dictionary(
                accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }

        func category(for transaction: MoneyTransaction) -> TransactionCategory? {
            transaction.categoryID.flatMap { categoriesByID[$0] }
        }

        func account(for transaction: MoneyTransaction) -> CashAccount? {
            accountsByID[transaction.accountID]
        }
    }
}

/// The tabs below the balance card, with the tab and trend metric they show.
///
/// Both pieces of state live here so that switching either redraws this part
/// alone, not the account screen above it with its balance and its filtering
/// of the period. The figures come in already worked out.
private struct AccountActivityTabs: View {
    let accountID: UUID
    let transactions: [MoneyTransaction]
    let transfers: [AccountTransfer]
    let range: TransactionRange
    let emptyNotice: LocalizedStringKey
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let deposits: [SavingsDeposit]
    let withdrawals: [SavingsWithdrawal]
    let holdings: [FundHolding]
    let sales: [FundSale]
    let instruments: [FundInstrument]

    @State private var selectedTab: AccountDetailTab = .transactions
    @State private var trendMetric: AccountTrendMetric = .net

    var body: some View {
        SegmentedTabs(
            label: "Account Detail",
            selection: $selectedTab,
            options: AccountDetailTab.allCases,
            title: \.title
        )
        .accessibilityIdentifier("account-detail-tabs")

        switch selectedTab {
        case .transactions:
            AccountTrendCard(
                points: SpendingTrend.points(of: transactions, in: range),
                metric: $trendMetric,
                range: range
            )

            TransactionListSection(
                title: "History",
                transactions: transactions,
                transfers: transfers,
                categories: categories,
                accounts: accounts,
                emptyNotice: emptyNotice,
                accessibilityIdentifierPrefix: "account-detail-transaction",
                showsCount: true
            )

        case .linkedInvestments:
            AccountLinkedInvestmentSections(
                accountID: accountID, deposits: deposits, withdrawals: withdrawals,
                holdings: holdings, sales: sales, instruments: instruments,
                accounts: accounts
            )
        }
    }
}

private struct AccountLinkedInvestmentSections: View {
    let accountID: UUID
    let deposits: [SavingsDeposit]
    let withdrawals: [SavingsWithdrawal]
    let holdings: [FundHolding]
    let sales: [FundSale]
    let instruments: [FundInstrument]
    let accounts: [CashAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            if linkedDeposits.isEmpty && linkedHoldings.isEmpty {
                ContentUnavailableView(
                    "No linked investments", systemImage: "chart.pie",
                    description: Text(
                        "Investments funded by this account or paid back into it appear here.")
                )
            } else {
                if !linkedDeposits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Savings", count: linkedDeposits.count)
                        ForEach(linkedDeposits) { deposit in
                            NavigationLink {
                                SavingsDepositDetailView(
                                    route: SavingsDepositRoute(depositID: deposit.id))
                            } label: {
                                SavingsDepositCard(
                                    deposit: deposit,
                                    sourceAccountName: accounts.first {
                                        $0.id == deposit.sourceAccountID
                                    }?.name,
                                    withdrawals: withdrawals
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("linked-savings-\(deposit.id.uuidString)")
                            .accessibilityHint("Opens this savings book")
                        }
                    }
                }
                ForEach([InvestmentSegment.funds, .gold, .crypto]) { segment in
                    let groups = groups(for: segment)
                    if !groups.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(segment.displayName, count: groups.count)
                            ForEach(groups) { group in
                                NavigationLink {
                                    FundGroupDetailView(
                                        route: FundGroupRoute(
                                            instrumentID: group.instrumentID,
                                            linkedAccountID: accountID
                                        ))
                                } label: {
                                    FundGroupCard(group: group)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("linked-investment-\(group.id)")
                                .accessibilityHint("Opens linked details")
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("account-detail-linked-investments")
    }

    private var linkedDeposits: [SavingsDeposit] {
        SavingsWithdrawalSummary.sortedDeposits(
            AccountLinkedInvestments.deposits(
                for: accountID, deposits: deposits, withdrawals: withdrawals),
            withdrawals: withdrawals, by: .date
        )
    }

    private var linkedHoldings: [FundHolding] {
        AccountLinkedInvestments.holdings(for: accountID, holdings: holdings, sales: sales)
    }

    private func groups(for segment: InvestmentSegment) -> [FundPositionGroup] {
        var matching = FundSummary.holdings(
            linkedHoldings, in: instruments, matching: segment.instrumentKinds)
        if segment == .funds {
            matching += FundSummary.unpriced(holdings: linkedHoldings, instruments: instruments)
        }
        return FundSummary.groups(
            holdings: matching, instruments: instruments, sales: sales, by: .date)
    }

    private func sectionHeader(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            Text(count.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
        }
    }
}
