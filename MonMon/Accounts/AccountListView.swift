import SwiftData
import SwiftUI

struct AccountListView: View {
    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @State private var editorMode: AccountEditorMode?
    @State private var isManagingTransfers = false
    @State private var isManagingDebts = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        if !allocationSlices.isEmpty {
                            AssetAllocationCard(slices: allocationSlices, liabilities: liabilities)
                        }

                        if accounts.isEmpty {
                            emptyState
                        } else {
                            accountsSection
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
                        title: "Add Account",
                        accessibilityIdentifier: "add-account"
                    ) {
                        editorMode = .add
                    }
                }
            }
            .navigationTitle("Home")
            .accessibilityIdentifier("account-list")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Transfers", systemImage: "arrow.left.arrow.right") {
                        isManagingTransfers = true
                    }
                    .accessibilityIdentifier("manage-transfers")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Debts", systemImage: "person.2.fill") {
                        isManagingDebts = true
                    }
                    .accessibilityIdentifier("manage-debts")
                }
            }
            .sheet(item: $editorMode) { mode in
                AccountEditorView(mode: mode)
            }
            .sheet(isPresented: $isManagingTransfers) {
                TransferListView()
            }
            .sheet(isPresented: $isManagingDebts) {
                DebtListView()
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var allocationSlices: [AssetAllocationSlice] {
        AssetAllocation.slices(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            instruments: instruments,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )
    }

    private var liabilities: Decimal {
        AssetAllocation.liabilities(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Build your cash picture")
                    .font(.title3.weight(.semibold))

                Text("Add cash and bank accounts to see everything in one calm overview.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            addAccountButton
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

    /// The header doubles as the way in to the Accounts screen, so the section
    /// the owner is already reading is also the door to the detail behind it.
    private var accountsSectionHeader: some View {
        NavigationLink {
            AccountsScreen()
        } label: {
            HStack(spacing: 8) {
                Text("Accounts")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)

                Text(accounts.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-accounts-screen")
        .accessibilityHint("Opens the Accounts screen.")
    }

    private var addAccountButton: some View {
        Button("Add Account", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-account")
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            accountsSectionHeader

            ForEach(accounts) { account in
                Button {
                    editorMode = .edit(account)
                } label: {
                    CashAccountCard(
                        account: account,
                        deposits: deposits,
                        holdings: holdings,
                        transactions: transactions,
                        transfers: transfers,
                        debts: debts,
                        payments: payments
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account-\(account.id.uuidString)")
                .accessibilityHint("Opens the account editor.")
            }
        }
    }
}

#if DEBUG
    #Preview("List · accounts") {
        AccountListView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("List · empty state") {
        AccountListView()
            .modelContainer(PreviewData.empty)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
