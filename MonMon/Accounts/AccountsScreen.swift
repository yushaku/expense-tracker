import SwiftData
import SwiftUI

/// Everything about where the money sits, one push in from the Home screen's
/// Accounts section: the ring that splits spendable cash by account, the
/// accounts themselves, and the history of money moved between them.
///
/// Home keeps the short version — a few cards and a total — so this screen is
/// where the detail lives rather than a second copy of the same summary.
struct AccountsScreen: View {
    @Environment(\.locale) private var locale

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @State private var accountEditorMode: AccountEditorMode?
    @State private var transferEditorMode: TransferEditorMode?
    @State private var transferRange = TransactionRange.month(containing: .now)

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    if accounts.isEmpty {
                        emptyState
                    } else {
                        if !balanceSlices.isEmpty {
                            AccountBalanceCard(slices: balanceSlices, overdraft: overdraft)
                        }

                        accountsSection

                        transfersSection
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Accounts")
        .accessibilityIdentifier("accounts-screen")
        .appSheet(item: $accountEditorMode) { mode in
            AccountEditorView(mode: mode)
        }
        .appSheet(item: $transferEditorMode) { mode in
            TransferEditorView(mode: mode)
        }
        .tint(MonMonTheme.accent)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Accounts",
                count: accounts.count,
                addLabel: "Add Account",
                addIdentifier: "accounts-screen-add-account",
                add: { accountEditorMode = .add }
            )

            ForEach(displayAccounts) { account in
                accountRow(account)
            }
        }
    }

    private var displayAccounts: [CashAccount] {
        CashAccountKind.allCases.flatMap { kind in
            accounts.filter { $0.kind == kind }
        }
    }

    private func accountRow(_ account: CashAccount) -> some View {
        NavigationLink(value: AccountDetailRoute(accountID: account.id)) {
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("accounts-screen-account-\(account.id.uuidString)")
        .accessibilityHint("Shows account details and activity.")
    }

    /// Transfers live here rather than only behind the Home toolbar because they
    /// are the one kind of movement that changes nothing but which account holds
    /// the money — the exact question this screen answers.
    ///
    /// The date filter is the transfer list's own, not the Spending screen's: a
    /// screen showing balances as they stand today can still be asked what moved
    /// last March.
    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Transfers",
                count: visibleTransfers.count,
                addLabel: "Add Transfer",
                addIdentifier: "accounts-screen-add-transfer",
                // A transfer needs somewhere to leave and somewhere to land, so
                // with one account there is nothing to add.
                addEnabled: accounts.count >= 2,
                add: { transferEditorMode = .add }
            ) {
                DateRangeFilterButton(range: $transferRange, identifierPrefix: "transfers")
            }

            transferPeriodHeader

            if visibleTransfers.isEmpty {
                noTransfersState
            } else {
                ForEach(visibleTransfers) { transfer in
                    Button {
                        transferEditorMode = .edit(transfer)
                    } label: {
                        TransferCard(
                            transfer: transfer,
                            sourceAccount: account(transfer.sourceAccountID),
                            destinationAccount: account(transfer.destinationAccountID)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("accounts-screen-transfer-\(transfer.id.uuidString)")
                    .accessibilityHint("Opens the transfer editor.")
                }
            }
        }
    }

    /// The add action sits in the section header rather than in a toolbar or a
    /// floating button, so each list carries its own way to grow and the screen
    /// needs no second place to look.
    private func sectionHeader<Filter: View>(
        _ title: String,
        count: Int,
        addLabel: String,
        addIdentifier: String,
        addEnabled: Bool = true,
        add: @escaping () -> Void,
        @ViewBuilder filter: () -> Filter = { EmptyView() }
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(count.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

            Spacer(minLength: 8)

            filter()

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MonMonTheme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(MonMonTheme.accent, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!addEnabled)
            .opacity(addEnabled ? 1 : 0.4)
            .accessibilityLabel(addLabel)
            .accessibilityIdentifier(addIdentifier)
        }
    }

    /// What the transfer list is showing. Changing it is the header's filter
    /// button, so this only has to say what is on screen.
    private var transferPeriodHeader: some View {
        Text(transferRange.title(in: locale).uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }

    private var emptyState: some View {
        placeholder(
            symbol: "wallet.bifold.fill",
            title: "No accounts yet",
            message: "Add normal accounts to see how your money is spread across them."
        ) {
            Button("Add Account", systemImage: "plus") {
                accountEditorMode = .add
            }
            .accessibilityIdentifier("accounts-screen-add-first-account")
        }
    }

    private var noTransfersState: some View {
        placeholder(
            symbol: "arrow.left.arrow.right",
            title: "Nothing moved \(transferRange.phrase(in: locale))",
            message: accounts.count < 2
                ? "A transfer needs somewhere to leave and somewhere to land, so add a second account first."
                : "Record money you shifted between your own accounts. Your total assets stay the same."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

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

    private var visibleTransfers: [AccountTransfer] {
        TransferSummary.inRange(transferRange, transfers: transfers)
    }

    private var balanceSlices: [AccountBalanceSlice] {
        AccountBalanceAllocation.slices(
            accounts: accounts,
            deposits: deposits,
            withdrawals: withdrawals,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }

    private var overdraft: Decimal {
        AssetAllocation.overdraft(
            accounts: accounts,
            deposits: deposits,
            withdrawals: withdrawals,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }
}

#if DEBUG
    #Preview("Accounts screen") {
        NavigationStack {
            AccountsScreen()
        }
        .modelContainer(PreviewData.populated)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Accounts screen · empty") {
        NavigationStack {
            AccountsScreen()
        }
        .modelContainer(PreviewData.empty)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
