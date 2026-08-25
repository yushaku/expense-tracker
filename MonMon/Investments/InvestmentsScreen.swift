import SwiftData
import SwiftUI

/// Which editor the screen has open. Every mode shares one `.sheet` rather than
/// hanging multiple sheets off the same view, which SwiftUI does not reliably
/// honour.
enum InvestmentEditorMode: Identifiable {
    case savings(SavingsEditorMode)
    case fund(FundEditorMode)
    case gold(FundEditorMode)

    var id: String {
        switch self {
        case .savings(let mode):
            "savings-\(mode.id)"
        case .fund(let mode):
            "fund-\(mode.id)"
        case .gold(let mode):
            "gold-\(mode.id)"
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

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Environment(\.locale) private var locale

    @State private var segment: InvestmentSegment
    @State private var editor: InvestmentEditorMode?

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
            .swipeBetweenSegments(
                selection: $segment,
                options: InvestmentSegment.allCases
            )
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
        .navigationDestination(for: FundGroupRoute.self) { route in
            FundGroupDetailView(route: route)
        }
        .navigationTitle("Investments")
        .accessibilityIdentifier("investments-list")
        .sheet(item: $editor) { mode in
            switch mode {
            case .savings(let savingsMode):
                SavingsEditorView(mode: savingsMode)
            case .fund(let fundMode):
                FundEditorView(mode: fundMode, kinds: [.fund, .etf])
            case .gold(let goldMode):
                FundEditorView(mode: goldMode, kinds: [.gold])
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

            Text("Savings books, funds, and gold will be split up here.")
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
                amount: AssetSummary.totalPrincipal(of: deposits)
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
        ]
        .filter { $0.amount > 0 }
    }

    private var total: Decimal {
        InvestmentSummary.total(
            deposits: deposits,
            holdings: holdings,
            instruments: instruments,
            sales: sales
        )
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
            SavingsSection(deposits: deposits, accounts: accounts) {
                add()
            } onEdit: { deposit in
                editor = .savings(.edit(deposit))
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
                addIdentifier: InvestmentSegment.funds.addIdentifier
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
                addIdentifier: InvestmentSegment.gold.addIdentifier
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
