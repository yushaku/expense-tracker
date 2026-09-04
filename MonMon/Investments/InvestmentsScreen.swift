import SwiftData
import SwiftUI

/// Which editor the screen has open. Every mode shares one `.sheet` rather than
/// hanging multiple sheets off the same view, which SwiftUI does not reliably
/// honour.
enum InvestmentEditorMode: Identifiable {
    case savings(SavingsEditorMode)
    case fund(FundEditorMode)
    case gold(FundEditorMode)
    case crypto(FundEditorMode)

    var id: String {
        switch self {
        case .savings(let mode):
            "savings-\(mode.id)"
        case .fund(let mode):
            "fund-\(mode.id)"
        case .gold(let mode):
            "gold-\(mode.id)"
        case .crypto(let mode):
            "crypto-\(mode.id)"
        }
    }
}

/// Savings books and fund holdings under one roof. The total at the top counts
/// both, and the picker below it decides which list the screen is showing.
///
/// Reached one push in from the Wealth screen, which carries the shorter
/// version — what the holdings come to inside the whole picture — so this is
/// where the holdings themselves live rather than a second copy of that total.
struct InvestmentsScreen: View {
    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Environment(\.locale) private var locale

    @Environment(\.modelContext) private var modelContext

    @State private var segment: InvestmentSegment
    @State private var editor: InvestmentEditorMode?
    @State private var refresher = FundPriceRefresher()

    /// Which list is in front on arrival. The Wealth screen names all three
    /// before pushing here, so landing on the one that was tapped saves the
    /// owner repeating the choice on the picker.
    init(segment: InvestmentSegment = .savings) {
        _segment = State(initialValue: segment)
    }

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    summaryCard

                    segmentPicker

                    selectedSection
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, FloatingAddButton.contentInset)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // An empty list already offers its own prominent add button, so
            // the floating one would only repeat it.
            if !isSelectedSectionEmpty {
                FloatingAddButton(
                    title: segment.addTitle,
                    accessibilityIdentifier: segment.addIdentifier
                ) {
                    add()
                }
            }
        }
        .navigationTitle("Investments")
        .accessibilityIdentifier("investments-list")
        // Opening a segment onto a price older than the day it should carry
        // fetches it. Keyed on the segment so switching to gold prices gold,
        // and bounded by the refresher: current prices ask for nothing, and a
        // ticker asked about minutes ago is not asked about again.
        .task(id: segment) {
            await refresher.refreshStale(
                instruments: pricedInstruments,
                holdings: holdings,
                sales: sales,
                in: modelContext
            )
        }
        .appSheet(item: $editor) { mode in
            switch mode {
            case .savings(let savingsMode):
                SavingsEditorView(mode: savingsMode)
            case .fund(let fundMode):
                FundEditorView(mode: fundMode, kinds: [.fund, .etf])
            case .gold(let goldMode):
                FundEditorView(mode: goldMode, kinds: [.gold])
            case .crypto(let cryptoMode):
                FundEditorView(mode: cryptoMode, kinds: [.crypto])
            }
        }
        .tint(MonMonTheme.accent)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TOTAL INVESTMENTS", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            if slices.isEmpty {
                emptySummary
            } else {
                AllocationDoughnut(
                    context: AppText.string(key: "Investments", in: locale).lowercased(),
                    items: slices.map { $0.doughnutItem(in: locale) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    /// Nothing invested yet draws no ring, so the card falls back to the plain
    /// zero rather than an empty circle.
    private var emptySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(VNDCurrency.format(total))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            Text("Savings books, funds, gold, and coins will be split up here.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// One wedge per kind, in the order the segments below are listed. A kind
    /// worth nothing is dropped rather than drawn as a hairline.
    private var slices: [AssetAllocationSlice] {
        [
            AssetAllocationSlice(
                kind: .savings,
                amount: AssetSummary.totalPrincipal(of: deposits, withdrawals: withdrawals)
            ),
            AssetAllocationSlice(
                kind: .funds,
                amount: FundSummary.totalMarketValue(
                    of: holdings,
                    instruments: instruments,
                    sales: sales,
                    kinds: [.fund, .etf]
                )
            ),
            AssetAllocationSlice(
                kind: .gold,
                amount: FundSummary.totalMarketValue(
                    of: holdings,
                    instruments: instruments,
                    sales: sales,
                    kinds: [.gold]
                )
            ),
            AssetAllocationSlice(
                kind: .crypto,
                amount: FundSummary.totalMarketValue(
                    of: holdings,
                    instruments: instruments,
                    sales: sales,
                    kinds: [.crypto]
                )
            ),
        ]
        .filter { $0.amount > 0 }
    }

    private var total: Decimal {
        InvestmentSummary.total(
            deposits: deposits,
            withdrawals: withdrawals,
            holdings: holdings,
            instruments: instruments,
            sales: sales
        )
    }

    /// What the last refresh did, in one line. A failure is what the line
    /// carries when there is one: an owner who asked for prices and got none
    /// needs to know why more than they need a count of the rest.
    private var refreshSummary: String? {
        guard !refresher.isRunning else {
            return nil
        }

        let outcomes = pricedInstruments.compactMap { refresher.outcomes[$0.id] }
        guard !outcomes.isEmpty else {
            return nil
        }

        if let failure = outcomes.first(where: \.isFailure) {
            return failure.message(in: locale)
        }

        let updated = outcomes.filter(\.isUpdate).count
        guard updated > 0 else {
            return outcomes.compactMap { $0.message(in: locale) }.first
        }
        return AppText.string("\(updated) updated", in: locale)
    }

    private var hasRefreshFailure: Bool {
        pricedInstruments.contains { refresher.outcomes[$0.id]?.isFailure == true }
    }

    /// Refresh is offered only where a request could achieve something: a held
    /// instrument of the kind on show, with automatic quotes left on.
    private var canRefresh: Bool {
        refresher.hasAnythingToRefresh(
            instruments: pricedInstruments,
            holdings: holdings,
            sales: sales
        )
    }

    /// The instruments the segment on show is priced from.
    private var pricedInstruments: [FundInstrument] {
        let kinds = segment.instrumentKinds
        return instruments.filter { kinds.contains($0.kind) }
    }

    private func refresh() {
        Task {
            await refresher.refresh(
                instruments: pricedInstruments,
                holdings: holdings,
                sales: sales,
                in: modelContext
            )
        }
    }

    private var segmentPicker: some View {
        SegmentedTabs(
            label: "Investment kind",
            selection: $segment,
            options: InvestmentSegment.allCases,
            title: \.displayName
        )
        .accessibilityIdentifier("investment-segment")
    }

    @ViewBuilder
    private var selectedSection: some View {
        switch segment {
        case .savings:
            SavingsSection(deposits: deposits, withdrawals: withdrawals, accounts: accounts) {
                add()
            }
        case .funds:
            FundSection(
                holdings: holdings,
                instruments: instruments,
                sales: sales,
                kinds: [.fund, .etf],
                sectionTitle: "Funds",
                itemNameKey: "fund",
                emptyTitle: "Track your funds and ETFs",
                emptyDescription: """
                    Add a holding to see what it cost, what it is worth today, and the gap \
                    between them.
                    """,
                emptySystemImage: "chart.line.uptrend.xyaxis",
                addTitle: InvestmentSegment.funds.addTitle,
                addIdentifier: InvestmentSegment.funds.addIdentifier,
                onRefresh: { refresh() },
                isRefreshing: refresher.isRunning,
                canRefresh: canRefresh,
                refreshMessage: refreshSummary,
                hasFailure: hasRefreshFailure
            ) {
                add()
            }
        case .gold:
            FundSection(
                holdings: holdings,
                instruments: instruments,
                sales: sales,
                kinds: [.gold],
                sectionTitle: "Gold",
                itemNameKey: "gold product",
                emptyTitle: "Track your physical gold",
                emptyDescription: """
                    Add gold to see its cost, shop buy valuation, and the visible buy/sell spread.
                    """,
                emptySystemImage: "seal.fill",
                addTitle: InvestmentSegment.gold.addTitle,
                addIdentifier: InvestmentSegment.gold.addIdentifier,
                onRefresh: { refresh() },
                isRefreshing: refresher.isRunning,
                canRefresh: canRefresh,
                refreshMessage: refreshSummary,
                hasFailure: hasRefreshFailure
            ) {
                add()
            }
        case .crypto:
            FundSection(
                holdings: holdings,
                instruments: instruments,
                sales: sales,
                kinds: [.crypto],
                sectionTitle: "Crypto",
                itemNameKey: "coin",
                emptyTitle: "Track your coins",
                emptyDescription: """
                    Add a coin to see what it cost, what it is worth in đồng today, and the gap \
                    between them.
                    """,
                emptySystemImage: "bitcoinsign.circle.fill",
                addTitle: InvestmentSegment.crypto.addTitle,
                addIdentifier: InvestmentSegment.crypto.addIdentifier,
                onRefresh: { refresh() },
                isRefreshing: refresher.isRunning,
                canRefresh: canRefresh,
                refreshMessage: refreshSummary,
                hasFailure: hasRefreshFailure
            ) {
                add()
            }
        }
    }

    private var isSelectedSectionEmpty: Bool {
        switch segment {
        case .savings:
            deposits.isEmpty
        case .funds:
            FundSummary.holdings(holdings, in: instruments, matching: [.fund, .etf]).isEmpty
        case .gold:
            FundSummary.holdings(holdings, in: instruments, matching: [.gold]).isEmpty
        case .crypto:
            FundSummary.holdings(holdings, in: instruments, matching: [.crypto]).isEmpty
        }
    }

    private func add() {
        switch segment {
        case .savings:
            editor = .savings(.add)
        case .funds:
            editor = .fund(.add)
        case .gold:
            editor = .gold(.add)
        case .crypto:
            editor = .crypto(.add)
        }
    }
}

#if DEBUG
    #Preview("Investments · savings") {
        NavigationStack {
            InvestmentsScreen()
        }
        .modelContainer(PreviewData.populated)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Investments · empty state") {
        NavigationStack {
            InvestmentsScreen()
        }
        .modelContainer(PreviewData.empty)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
