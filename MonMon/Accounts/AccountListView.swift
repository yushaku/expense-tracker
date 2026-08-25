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

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @State private var editorMode: AccountEditorMode?
    @State private var debtEditorMode: DebtEditorMode?

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        if !historyPoints.isEmpty {
                            AssetGrowthCard(points: historyPoints)
                        }

                        if !allocationSlices.isEmpty || !liabilitySlices.isEmpty {
                            AssetAllocationCard(
                                slices: allocationSlices,
                                liabilities: liabilitySlices
                            )
                        }

                        if accounts.isEmpty {
                            emptyState
                        } else {
                            accountsSection
                        }

                        debtsSection
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
            .compactRootNavigationTitle("Report")
            .accessibilityIdentifier("account-list")
            .navigationDestination(for: DebtRoute.self) { route in
                DebtDetailView(route: route)
            }
            .sheet(item: $editorMode) { mode in
                AccountEditorView(mode: mode)
            }
            .sheet(item: $debtEditorMode) { mode in
                DebtEditorView(mode: mode)
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
            payments: payments,
            sales: sales
        )
    }

    private var historyPoints: [AssetHistoryPoint] {
        AssetHistory.points(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            instruments: instruments,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales,
            asOf: .now
        )
    }

    private var liabilitySlices: [LiabilityAllocationSlice] {
        AssetAllocation.liabilitySlices(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
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
                        payments: payments,
                        sales: sales
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account-\(account.id.uuidString)")
                .accessibilityHint("Opens the account editor.")
            }
        }
    }

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Debts")
                    .font(.title3.weight(.semibold))

                Text(debts.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer(minLength: 8)

                Button {
                    debtEditorMode = .add
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MonMonTheme.onAccent)
                        .frame(width: 32, height: 32)
                        .background(MonMonTheme.accent, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(accounts.isEmpty)
                .opacity(accounts.isEmpty ? 0.4 : 1)
                .accessibilityLabel("Add Debt")
                .accessibilityIdentifier("home-add-debt")
            }

            if debts.isEmpty {
                Text(
                    accounts.isEmpty
                        ? "Add an account before recording debt."
                        : "No debts recorded."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .padding(.vertical, 8)
            } else {
                ForEach(sortedDebts) { debt in
                    NavigationLink(value: DebtRoute(debtID: debt.id)) {
                        debtCard(for: debt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home-debt-\(debt.id.uuidString)")
                    .accessibilityHint("Opens the debt and its payments.")
                }
            }
        }
    }

    private var sortedDebts: [Debt] {
        DebtSummary.sortedForDisplay(debts, payments: payments)
    }

    private func debtCard(for debt: Debt) -> some View {
        let asOf = Date.now

        return DebtCard(
            debt: debt,
            outstanding: DebtSummary.outstanding(for: debt, payments: payments),
            paid: DebtSummary.paid(for: debt, payments: payments),
            progress: DebtSummary.progress(for: debt, payments: payments),
            accountName: accountName(debt.accountID),
            isOverdue: DebtSummary.isOverdue(debt, payments: payments, asOf: asOf),
            projectedInterest: debt.projectedInterest(asOf: asOf)
        )
    }

    private func accountName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name
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
