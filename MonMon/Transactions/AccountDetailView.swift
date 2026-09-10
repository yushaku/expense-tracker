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

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

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

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    let route: AccountDetailRoute

    @State private var accountEditorMode: AccountEditorMode?
    @State private var transactionEditorMode: TransactionEditorMode?
    @State private var transactionActions = TransactionActions()
    @State private var selectedTab: AccountDetailTab = .transactions
    @State private var selectedRange = TransactionRange.month(containing: .now)
    @State private var trendMetric: AccountTrendMetric = .net

    private var account: CashAccount? {
        accounts.first { $0.id == route.accountID }
    }

    var body: some View {
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
            category: category(for:),
            account: transactionAccount(for:),
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
        let accountTransactions = accountTransactions(for: account)
        let accountTransfers = accountTransfers(for: account)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                CashAccountCard(
                    account: account,
                    deposits: deposits,
                    withdrawals: withdrawals,
                    holdings: holdings,
                    transactions: transactions,
                    transfers: transfers,
                    debts: debts,
                    payments: payments,
                    sales: sales
                )

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
                        points: trendPoints(for: account),
                        metric: $trendMetric,
                        range: selectedRange
                    )

                    TransactionListSection(
                        title: "History",
                        transactions: accountTransactions,
                        transfers: accountTransfers,
                        categories: categories,
                        accounts: accounts,
                        emptyNotice: emptyTransactionNotice,
                        accessibilityIdentifierPrefix: "account-detail-transaction",
                        showsCount: true
                    )

                case .linkedInvestments:
                    AccountLinkedInvestmentSections(
                        accountID: account.id, deposits: deposits, withdrawals: withdrawals,
                        holdings: holdings, sales: sales, instruments: instruments,
                        accounts: accounts
                    )
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func trendPoints(for account: CashAccount) -> [SpendingTrendPoint] {
        SpendingTrend.points(
            of: AccountActivityItem.transactions(
                for: account.id,
                during: selectedRange,
                in: transactions
            ),
            in: selectedRange
        )
    }

    private func accountTransactions(for account: CashAccount) -> [MoneyTransaction] {
        AccountActivityItem.transactions(
            for: account.id,
            during: selectedRange,
            in: transactions
        )
    }

    private var emptyTransactionNotice: LocalizedStringKey {
        "No transactions recorded \(selectedRange.phrase(in: locale, dateFormat: dateFormat))."
    }

    private func accountTransfers(for account: CashAccount) -> [AccountTransfer] {
        AccountActivityItem.transfers(for: account.id, in: transfers)
            .filter { selectedRange.contains($0.occurredAt) }
    }

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        guard let categoryID = transaction.categoryID else {
            return nil
        }
        return categories.first { $0.id == categoryID }
    }

    private func transactionAccount(for transaction: MoneyTransaction) -> CashAccount? {
        account(transaction.accountID)
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
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
