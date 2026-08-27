import SwiftData
import SwiftUI

/// Everything the owner has, in one picture: how it splits between cash,
/// savings, funds, gold and what is lent out, then concise account, investment,
/// and debt summaries.
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

                        accountsSection

                        investmentsSection

                        debtsSection
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .compactRootNavigationTitle("Wealth")
            .accessibilityIdentifier("wealth")
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

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Accounts")

            summaryNavigationRow(
                title: "Total balance",
                amount: accountsTotal,
                systemImage: "wallet.bifold.fill",
                tint: MonMonTheme.accent,
                accessibilityIdentifier: "open-accounts-screen",
                accessibilityHint: "Opens the Accounts screen."
            ) {
                AccountsScreen()
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func summaryNavigationRow<Destination: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        amount: Decimal,
        systemImage: String,
        tint: Color,
        accessibilityIdentifier: String,
        accessibilityHint: LocalizedStringKey,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
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

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
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
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(accessibilityHint)
    }

    private var accountsTotal: Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            deposits: deposits,
            holdings: holdings,
            withdrawals: withdrawals,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }

    /// The three places parked money sits, each worth what it is worth today and
    /// each a door into the list behind it. The figures repeat slices the
    /// allocation ring already draws, so the rows are doors rather than new
    /// claims.
    private var investmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Investments")

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
        summaryNavigationRow(
            title: title,
            subtitle: countLabel(count, for: segment),
            amount: amount,
            systemImage: systemImage,
            tint: tint,
            accessibilityIdentifier: "open-investments-\(segment.rawValue)",
            accessibilityHint: "Opens the Investments screen."
        ) {
            InvestmentsScreen(segment: segment)
        }
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

    private var debtsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Debts")

            summaryNavigationRow(
                title: DebtDirection.borrowed.displayName,
                amount: outstandingDebtTotal(.borrowed),
                systemImage: DebtDirection.borrowed.symbolName,
                tint: MonMonTheme.credit,
                accessibilityIdentifier: "open-debts-borrowed",
                accessibilityHint: "Opens borrowed debts."
            ) {
                DebtListView(direction: .borrowed)
            }

            summaryNavigationRow(
                title: DebtDirection.lent.displayName,
                amount: outstandingDebtTotal(.lent),
                systemImage: DebtDirection.lent.symbolName,
                tint: MonMonTheme.lent,
                accessibilityIdentifier: "open-debts-lent",
                accessibilityHint: "Opens lent debts."
            ) {
                DebtListView(direction: .lent)
            }
        }
    }

    private func outstandingDebtTotal(_ direction: DebtDirection) -> Decimal {
        DebtSummary.totalOutstanding(
            of: debts,
            payments: payments,
            direction: direction
        )
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
