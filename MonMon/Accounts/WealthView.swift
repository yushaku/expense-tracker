import SwiftData
import SwiftUI

/// Everything the owner has, in one picture: how it splits between cash,
/// savings, funds, gold and what is lent out, then the accounts and the debts
/// themselves.
///
/// The detail behind each part lives one push in — the Accounts screen, the
/// Investments screen, a debt and its payments — so this screen stays a summary
/// rather than a second copy of any of them.
struct WealthView: View {
    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

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

                        investmentsSection

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
            .compactRootNavigationTitle("Wealth")
            .accessibilityIdentifier("wealth")
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
            withdrawals: withdrawals,
            holdings: holdings,
            instruments: instruments,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }

    private var liabilitySlices: [LiabilityAllocationSlice] {
        AssetAllocation.liabilitySlices(
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
                .accessibilityIdentifier("account-\(account.id.uuidString)")
                .accessibilityHint("Opens the account editor.")
            }
        }
    }

    /// The three places parked money sits, each worth what it is worth today and
    /// each a door into the list behind it. The figures repeat slices the
    /// allocation ring already draws, so the rows are doors rather than new
    /// claims.
    private var investmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Investments")
                    .font(.title3.weight(.semibold))

                Spacer(minLength: 8)

                Text(VNDCurrency.format(investedTotal))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            investmentRow(
                .savings,
                title: "Savings",
                systemImage: "building.columns.fill",
                tint: MonMonTheme.savings,
                amount: savingsTotal,
                count: deposits.count
            )

            investmentRow(
                .funds,
                title: "Funds",
                systemImage: "chart.line.uptrend.xyaxis",
                tint: MonMonTheme.funds,
                amount: fundsTotal,
                count: fundHoldings.count
            )

            investmentRow(
                .gold,
                title: "Gold",
                systemImage: "seal.fill",
                tint: MonMonTheme.Hue.peach,
                amount: goldTotal,
                count: goldHoldings.count
            )
        }
    }

    private func investmentRow(
        _ segment: InvestmentSegment,
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        amount: Decimal,
        count: Int
    ) -> some View {
        NavigationLink {
            InvestmentsScreen(segment: segment)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)

                    Text(countLabel(count, for: segment))
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Text(VNDCurrency.format(amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-investments-\(segment.rawValue)")
        .accessibilityHint("Opens the Investments screen.")
    }

    /// What a row counts is what its list holds, so the word follows the
    /// segment rather than one plural covering three different things.
    private func countLabel(_ count: Int, for segment: InvestmentSegment) -> LocalizedStringKey {
        switch segment {
        case .savings:
            "\(count) books"
        case .funds:
            "\(count) holdings"
        case .gold:
            "\(count) products"
        }
    }

    private var savingsTotal: Decimal {
        AssetSummary.totalPrincipal(of: deposits, withdrawals: withdrawals)
    }

    private var fundHoldings: [FundHolding] {
        FundSummary.holdings(holdings, in: instruments, matching: [.fund, .etf])
    }

    private var goldHoldings: [FundHolding] {
        FundSummary.holdings(holdings, in: instruments, matching: [.gold])
    }

    private var fundsTotal: Decimal {
        FundSummary.totalMarketValue(of: fundHoldings, instruments: instruments, sales: sales)
    }

    private var goldTotal: Decimal {
        FundSummary.totalMarketValue(of: goldHoldings, instruments: instruments, sales: sales)
    }

    private var investedTotal: Decimal {
        InvestmentSummary.total(
            deposits: deposits,
            withdrawals: withdrawals,
            holdings: holdings,
            instruments: instruments,
            sales: sales
        )
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
    #Preview("Wealth") {
        WealthView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Wealth · empty state") {
        WealthView()
            .modelContainer(PreviewData.empty)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
