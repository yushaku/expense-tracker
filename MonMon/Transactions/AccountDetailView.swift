import SwiftData
import SwiftUI

struct AccountDetailRoute: Hashable {
    let accountID: UUID
}

struct AccountDetailView: View {
    @Environment(\.dismiss) private var dismiss

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
        .onChange(of: account == nil) { _, isGone in
            if isGone {
                dismiss()
            }
        }
        .tint(MonMonTheme.accent)
    }

    private func content(for account: CashAccount) -> some View {
        ScrollView {
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

                AccountLinkedSourcesCard(rows: linkedSources(for: account))

                activitySection(for: account)
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func activitySection(for account: CashAccount) -> some View {
        let activity = activity(for: account)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Activity")
                    .font(.title3.weight(.semibold))

                Text(activity.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer(minLength: 0)
            }

            if activity.isEmpty {
                emptyActivityState
            } else {
                ForEach(activity) { item in
                    activityRow(item, account: account)
                }
            }
        }
    }

    private var emptyActivityState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 56, height: 56)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text("No activity recorded for this account.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("account-detail-activity-empty")
    }

    @ViewBuilder
    private func activityRow(_ item: AccountActivityItem, account: CashAccount) -> some View {
        switch item {
        case .transaction(let transaction):
            TransactionItem(
                transaction: transaction,
                category: category(for: transaction),
                account: account,
                accessibilityIdentifier: "account-detail-transaction-\(transaction.id.uuidString)"
            )

        case .transfer(let transfer):
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

    private func activity(for account: CashAccount) -> [AccountActivityItem] {
        AccountActivityItem.items(
            for: account.id,
            transactions: transactions,
            transfers: transfers
        )
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
