import SwiftData
import SwiftUI

/// Account allocation and management embedded directly in Wealth.
struct WealthAccountsSection: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            if accounts.isEmpty {
                emptyState
            } else {
                if !balanceSlices.isEmpty {
                    AccountBalanceCard(slices: balanceSlices, overdraft: overdraft)
                }
                accountsSection
            }
        }
        .accessibilityIdentifier("wealth-accounts")
        .appSheet(item: $accountEditorMode) { mode in
            AccountEditorView(mode: mode)
        }
        .tint(MonMonTheme.accent)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Accounts",
                count: accounts.count,
                addLabel: "Add Account",
                addIdentifier: "wealth-add-account",
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
        .accessibilityIdentifier("wealth-account-\(account.id.uuidString)")
        .accessibilityHint("Shows account details and activity.")
    }

    /// The add action sits in the section header rather than in a toolbar or a
    /// floating button, so each list carries its own way to grow and the screen
    /// needs no second place to look.
    private func sectionHeader(
        _ title: LocalizedStringKey,
        count: Int,
        addLabel: LocalizedStringKey,
        addIdentifier: String,
        add: @escaping () -> Void
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

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MonMonTheme.onAccent)
                    .frame(width: 32, height: 32)
                    .background(MonMonTheme.accent, in: Circle())
                    .padding(6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(addLabel)
            .accessibilityIdentifier(addIdentifier)
        }
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
            .accessibilityIdentifier("wealth-add-first-account")
        }
    }

    private func placeholder<Action: View>(
        symbol: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
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
    #Preview("Wealth accounts") {
        NavigationStack {
            WealthAccountsSection()
        }
        .modelContainer(PreviewData.populated)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Wealth accounts · empty") {
        NavigationStack {
            WealthAccountsSection()
        }
        .modelContainer(PreviewData.empty)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
