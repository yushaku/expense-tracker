import SwiftData
import SwiftUI

/// Where a summary row on the Wealth screen leads.
///
/// A value rather than a view. A link that carries its own destination ties that
/// destination to the row it was built from, and these rows sit in a lazy stack
/// that rebuilds whenever the figures above them are recomputed — which drops
/// whatever was pushed beyond it, sending an owner two screens in back out to
/// one. The stack keeps the route instead, so nothing below depends on the row
/// that started it still being on screen.
enum WealthDestination: Hashable {
    case accounts
    case investments(InvestmentSegment)
    case debts(DebtDirection)
}

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
            .navigationDestination(for: WealthDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsScreen()
                case .investments(let segment):
                    InvestmentsScreen(segment: segment)
                case .debts(let direction):
                    DebtListView(direction: direction)
                }
            }
            .navigationDestination(for: AccountDetailRoute.self) { route in
                AccountDetailView(route: route)
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

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Accounts")

            ForEach(CashAccountKind.allCases, id: \.rawValue) { kind in
                accountRow(kind)
            }
        }
    }

    private func accountRow(_ kind: CashAccountKind) -> some View {
        summaryNavigationRow(
            title: kind.displayName,
            amount: accountsTotal(kind),
            systemImage: kind.iconName,
            tint: kind.tint,
            accessibilityIdentifier: "open-accounts-\(kind.rawValue)",
            accessibilityHint: "Opens the Accounts screen.",
            destination: .accounts
        )
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func summaryNavigationRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        amount: Decimal,
        systemImage: String,
        tint: Color,
        accessibilityIdentifier: String,
        accessibilityHint: LocalizedStringKey,
        destination: WealthDestination
    ) -> some View {
        NavigationLink(value: destination) {
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

    private func accountsTotal(_ kind: CashAccountKind) -> Decimal {
        CashBalanceSummary.totalAvailable(
            of: accounts,
            matching: kind,
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

    /// The four places parked money sits, each worth what it is worth today and
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

            investmentRow(
                .crypto,
                title: "Crypto",
                systemImage: "bitcoinsign.circle.fill",
                tint: MonMonTheme.crypto,
                amount: cryptoTotal,
                count: cryptoHoldings.count
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
            accessibilityHint: "Opens the Investments screen.",
            destination: .investments(segment)
        )
    }

    /// What a row counts is what its list holds, so the word follows the
    /// segment rather than one plural covering four different things.
    private func countLabel(_ count: Int, for segment: InvestmentSegment) -> LocalizedStringKey {
        switch segment {
        case .savings:
            "\(count) books"
        case .funds:
            "\(count) holdings"
        case .gold:
            "\(count) products"
        case .crypto:
            "\(count) coins"
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

    private var cryptoHoldings: [FundHolding] {
        FundSummary.holdings(holdings, in: instruments, matching: [.crypto])
    }

    private var fundsTotal: Decimal {
        FundSummary.totalMarketValue(of: fundHoldings, instruments: instruments, sales: sales)
    }

    private var goldTotal: Decimal {
        FundSummary.totalMarketValue(of: goldHoldings, instruments: instruments, sales: sales)
    }

    private var cryptoTotal: Decimal {
        FundSummary.totalMarketValue(of: cryptoHoldings, instruments: instruments, sales: sales)
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
                accessibilityHint: "Opens borrowed debts.",
                destination: .debts(.borrowed)
            )

            summaryNavigationRow(
                title: DebtDirection.lent.displayName,
                amount: outstandingDebtTotal(.lent),
                systemImage: DebtDirection.lent.symbolName,
                tint: MonMonTheme.lent,
                accessibilityIdentifier: "open-debts-lent",
                accessibilityHint: "Opens lent debts.",
                destination: .debts(.lent)
            )
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
