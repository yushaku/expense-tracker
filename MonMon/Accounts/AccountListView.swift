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

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @State private var editorMode: AccountEditorMode?
    @State private var isManagingTransfers = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        totalCard

                        if !allocationSlices.isEmpty {
                            AssetAllocationCard(slices: allocationSlices, debt: debt)
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
            }
            .sheet(item: $editorMode) { mode in
                AccountEditorView(mode: mode)
            }
            .sheet(isPresented: $isManagingTransfers) {
                TransferListView()
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TOTAL ASSETS", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(netWorth))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Cash \(VNDCurrency.format(availableCash))",
                    systemImage: "banknote.fill"
                )
                .font(.subheadline.weight(.medium))

                Label(
                    "Savings \(VNDCurrency.format(savingsPrincipal))",
                    systemImage: "building.columns.fill"
                )
                .font(.subheadline.weight(.medium))

                Label(
                    "Funds \(VNDCurrency.format(fundsMarketValue))",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.subheadline.weight(.medium))

                Label(accountCountLabel, systemImage: "rectangle.stack.fill")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var availableCash: Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers
        )
    }

    private var savingsPrincipal: Decimal {
        AssetSummary.totalPrincipal(of: deposits)
    }

    private var fundsMarketValue: Decimal {
        FundSummary.totalMarketValue(of: holdings)
    }

    private var netWorth: Decimal {
        AssetSummary.netWorth(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers
        )
    }

    private var allocationSlices: [AssetAllocationSlice] {
        AssetAllocation.slices(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers
        )
    }

    private var debt: Decimal {
        AssetAllocation.debt(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers
        )
    }

    private var accountCountLabel: String {
        switch accounts.count {
        case 0:
            "Ready for your first account"
        case 1:
            "Across 1 account"
        default:
            "Across \(accounts.count) accounts"
        }
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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

    private var addAccountButton: some View {
        Button("Add Account", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-account")
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(accounts.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
            }

            ForEach(accounts) { account in
                Button {
                    editorMode = .edit(account)
                } label: {
                    CashAccountCard(
                        account: account,
                        deposits: deposits,
                        holdings: holdings,
                        transactions: transactions,
                        transfers: transfers
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
