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

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var recurringRules: [RecurringRule]

    let route: AccountDetailRoute

    @State private var accountEditorMode: AccountEditorMode?
    @State private var transactionEditorMode: TransactionEditorMode?
    @State private var transferEditorMode: TransferEditorMode?
    @State private var transactionActions = TransactionActions()
    @State private var selectedTab: AccountDetailTab = .transactions

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
                ToolbarItem(placement: .primaryAction) {
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
        .appSheet(item: $transferEditorMode) { mode in
            TransferEditorView(mode: mode)
        }
        .transactionActions(
            transactionActions,
            category: category(for:),
            account: transactionAccount(for:),
            onEdit: { transactionEditorMode = .edit($0) }
        )
        .tint(MonMonTheme.accent)
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
                    TransactionListSection(
                        title: "History",
                        transactions: accountTransactions,
                        categories: categories,
                        accounts: accounts,
                        emptyNotice: "No transactions recorded for this account.",
                        accessibilityIdentifierPrefix: "account-detail-transaction",
                        showsCount: true
                    )

                    if !accountTransfers.isEmpty {
                        transferHistorySection(accountTransfers)
                    }

                case .linkedInvestments:
                    AccountLinkedSourcesCard(rows: linkedSources(for: account))
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func transferHistorySection(_ accountTransfers: [AccountTransfer]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Transfers")
                    .font(.title3.weight(.semibold))

                Text(accountTransfers.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer(minLength: 0)
            }

            ForEach(accountTransfers) { transfer in
                Button {
                    transferEditorMode = .edit(transfer)
                } label: {
                    TransferCard(
                        transfer: transfer,
                        sourceAccount: self.account(transfer.sourceAccountID),
                        destinationAccount: self.account(transfer.destinationAccountID)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account-detail-transfer-\(transfer.id.uuidString)")
                .accessibilityHint("Opens the transfer editor.")
            }
        }
    }

    private func accountTransactions(for account: CashAccount) -> [MoneyTransaction] {
        AccountActivityItem.transactions(for: account.id, in: transactions)
    }

    private func accountTransfers(for account: CashAccount) -> [AccountTransfer] {
        AccountActivityItem.transfers(for: account.id, in: transfers)
    }

    private func linkedSources(for account: CashAccount) -> [AccountLinkedSourceRow] {
        AccountLinkedSourceSummary.rows(
            for: account,
            deposits: deposits,
            withdrawals: withdrawals,
            holdings: holdings,
            sales: sales,
            debts: debts,
            payments: payments,
            recurringRules: recurringRules
        )
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

private struct AccountLinkedSourcesCard: View {
    let rows: [AccountLinkedSourceRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("LINKED SOURCES", systemImage: "link")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            if rows.isEmpty {
                Text("No savings, funds, debts, or recurring rules use this account.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(rows) { row in
                        linkedSourceRow(row)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("account-detail-linked-sources")
    }

    private func linkedSourceRow(_ row: AccountLinkedSourceRow) -> some View {
        HStack(spacing: 14) {
            Image(systemName: row.kind.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.kind.tint)
                .frame(width: 40, height: 40)
                .background(row.kind.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.kind.title)
                    .font(.subheadline.weight(.semibold))

                Text(row.kind.description)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(row.count.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(row.kind.tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(row.kind.tint.opacity(0.16), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }
}

private extension AccountLinkedSourceKind {
    var title: LocalizedStringKey {
        switch self {
        case .savings: "Savings"
        case .funds: "Funds"
        case .debts: "Debts"
        case .recurring: "Recurring"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .savings: "Deposits funded or withdrawals received"
        case .funds: "Holdings funded or sale proceeds received"
        case .debts: "Debts opened or payments recorded"
        case .recurring: "Rules that record into this account"
        }
    }

    var iconName: String {
        switch self {
        case .savings: "banknote.fill"
        case .funds: "chart.line.uptrend.xyaxis"
        case .debts: "person.2.fill"
        case .recurring: "repeat"
        }
    }

    var tint: Color {
        switch self {
        case .savings: MonMonTheme.savings
        case .funds: MonMonTheme.funds
        case .debts: MonMonTheme.lent
        case .recurring: MonMonTheme.accent
        }
    }
}
