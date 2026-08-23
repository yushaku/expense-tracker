import SwiftData
import SwiftUI

struct FundListView: View {
    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editorMode: FundEditorMode?

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        summaryCard

                        if holdings.isEmpty {
                            emptyState
                        } else {
                            holdingsSection
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
                if !holdings.isEmpty {
                    FloatingAddButton(
                        title: "Add Holding",
                        accessibilityIdentifier: "add-fund"
                    ) {
                        editorMode = .add
                    }
                }
            }
            .navigationTitle("Funds")
            .accessibilityIdentifier("funds-list")
            .sheet(item: $editorMode) { mode in
                FundEditorView(mode: mode)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TOTAL FUNDS", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(marketValue))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Cost basis \(VNDCurrency.format(costBasis))",
                    systemImage: "cart.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)

                Label(
                    profitLossDescription,
                    systemImage: isGain ? "arrow.up.right" : "arrow.down.right"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isGain ? MonMonTheme.gain : MonMonTheme.danger)

                Label(holdingCountLabel, systemImage: "rectangle.stack.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
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

    private var marketValue: Decimal {
        FundSummary.totalMarketValue(of: holdings)
    }

    private var costBasis: Decimal {
        FundSummary.totalCostBasis(of: holdings)
    }

    private var profitLoss: Decimal {
        FundSummary.totalUnrealizedProfitLoss(of: holdings)
    }

    private var isGain: Bool {
        profitLoss >= 0
    }

    /// The arrow symbol and the explicit sign carry the meaning; the tint only
    /// reinforces it, so the figure still reads with colour ignored.
    private var profitLossDescription: String {
        let label = isGain ? "Unrealized gain" : "Unrealized loss"
        let sign = isGain ? "+" : "−"
        return "\(label) \(sign)\(VNDCurrency.format(abs(profitLoss)))"
    }

    private var holdingCountLabel: String {
        switch holdings.count {
        case 0:
            "Ready for your first holding"
        case 1:
            "Across 1 holding"
        default:
            "Across \(holdings.count) holdings"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.funds.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Track your funds and ETFs")
                    .font(.title3.weight(.semibold))

                Text(
                    "Add a holding to see what it cost, what it is worth today, and the gap between them."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            addHoldingButton
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

    private func accountName(for holding: FundHolding) -> String? {
        guard let sourceAccountID = holding.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }?.name
    }

    private var addHoldingButton: some View {
        Button("Add Holding", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-fund")
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(holdings.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.funds)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.funds.opacity(0.16), in: Capsule())
            }

            ForEach(holdings) { holding in
                Button {
                    editorMode = .edit(holding)
                } label: {
                    FundHoldingCard(
                        holding: holding,
                        sourceAccountName: accountName(for: holding)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fund-\(holding.id.uuidString)")
                .accessibilityHint("Opens this holding for editing")
            }
        }
    }
}

#if DEBUG
    #Preview("Funds · holdings") {
        FundListView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Funds · empty state") {
        FundListView()
            .modelContainer(PreviewData.empty)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
