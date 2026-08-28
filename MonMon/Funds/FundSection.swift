import SwiftUI

/// The funds half of the Investments screen: what the holdings cost against
/// what they are worth, followed by a card per holding. The screen around it
/// owns the scroll, the running total, and the editor sheet.
struct FundSection: View {
    @Environment(\.locale) private var locale

    let holdings: [FundHolding]
    /// The catalogue the holdings are priced from. Passed in rather than
    /// queried here so the section stays a plain view over values.
    let instruments: [FundInstrument]
    /// Every sale, for the same reason: what is still held is derived from
    /// these, so a section handed the holdings alone would report closed
    /// positions as open.
    let sales: [FundSale]
    let kinds: [FundInstrumentKind]
    let sectionTitle: LocalizedStringKey
    /// The key naming what one row holds — "fund" or "gold product". Kept as a
    /// key rather than a word, so the sentences built from it below read in the
    /// language on show.
    let itemNameKey: String
    let emptyTitle: LocalizedStringKey
    let emptyDescription: LocalizedStringKey
    let emptySystemImage: String
    let addTitle: LocalizedStringKey
    let addIdentifier: String
    /// Refetches the prices this section is valued from. `nil` where nothing
    /// offers one — a preview, or a section that only reports.
    var onRefresh: (() -> Void)?
    var isRefreshing = false
    /// Whether a request could achieve anything: something held, with automatic
    /// quotes left on. The icon stays visible and goes dim when it could not,
    /// rather than appearing and disappearing as positions are sold.
    var canRefresh = false
    /// What the last refresh came to, when it is worth saying. Failures are.
    var refreshMessage: String?
    /// Whether the message above reports a failure rather than a count. Passed
    /// in because the outcomes belong to the refresher, not to this view.
    var hasFailure = false
    let onAdd: () -> Void

    var body: some View {
        if displayedHoldings.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                detailCard

                if !unpriced.isEmpty {
                    unpricedBanner
                }

                holdingsSection
            }
        }
    }

    private var detailCard: some View {
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
        .accessibilityElement(children: .combine)
    }

    /// Positions the totals above cannot value. Market value counts them as
    /// zero, which understates the figure, so the screen says so rather than
    /// letting a quiet undercount pass for a number.
    private var unpriced: [FundHolding] {
        FundSummary.unpriced(holdings: displayedHoldings, instruments: instruments)
    }

    private var unpricedBanner: some View {
        Label(unpricedDescription, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(MonMonTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
            }
            .accessibilityIdentifier("unpriced-holdings")
    }

    private var unpricedDescription: LocalizedStringKey {
        let count = unpriced.count

        let cost = VNDCurrency.format(
            FundSummary.unpricedCostBasis(holdings: displayedHoldings, instruments: instruments)
        )
        return """
            \(count) positions have no instrument, so \(cost) of cost is counted as worth \
            nothing. Open each one and pick what it is held in.
            """
    }

    /// The cost of what is still held, so the gap below it is a gap between two
    /// figures about the same units.
    private var costBasis: Decimal {
        FundSummary.totalOpenCostBasis(of: displayedHoldings, sales: sales)
    }

    private var realizedProfitLoss: Decimal {
        FundSaleSummary.totalRealizedProfitLoss(
            of: FundSaleSummary.sales(of: displayedHoldings, sales: sales),
            holdings: displayedHoldings
        )
    }

    private var hasRealized: Bool {
        !FundSaleSummary.sales(of: displayedHoldings, sales: sales).isEmpty
    }

    private var profitLoss: Decimal {
        FundSummary.totalUnrealizedProfitLoss(
            of: displayedHoldings,
            instruments: instruments,
            sales: sales
        )
    }

    private var isGain: Bool {
        profitLoss >= 0
    }

    /// The arrow symbol and the explicit sign carry the meaning; the tint only
    /// reinforces it, so the figure still reads with colour ignored.
    private var profitLossDescription: LocalizedStringKey {
        let label = isGain ? "Unrealized gain" : "Unrealized loss"
        let sign = isGain ? "+" : "−"
        return "\(label) \(sign)\(VNDCurrency.format(abs(profitLoss)))"
    }

    private var itemNoun: String {
        AppText.string(key: itemNameKey, in: locale)
    }

    private var groups: [FundPositionGroup] {
        FundSummary.groups(holdings: displayedHoldings, instruments: instruments, sales: sales)
    }

    /// Counts both, because they answer different questions: how many funds are
    /// held, and how many purchases went into them.
    private var holdingCountLabel: LocalizedStringKey {
        switch displayedHoldings.count {
        case 0:
            return "Ready for your first holding"
        default:
            return "Across \(groups.count) \(itemNoun) · \(displayedHoldings.count) positions"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: emptySystemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.funds.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(emptyTitle)
                    .font(.title3.weight(.semibold))

                Text(emptyDescription)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(addTitle, systemImage: "plus", action: onAdd)
                .accessibilityIdentifier(addIdentifier)
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

    /// An icon on the title's line rather than a button of its own above the
    /// list: refreshing is something done to what is already on screen, and a
    /// labelled button cost a row of height to say what the arrow says.
    private func refreshButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(width: 32, height: 32)
            .background(MonMonTheme.funds.opacity(0.16), in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.funds)
        .disabled(isRefreshing || !canRefresh)
        .opacity(canRefresh || isRefreshing ? 1 : 0.4)
        .accessibilityLabel("Refresh prices")
        .accessibilityIdentifier("refresh-investment-quotes")
    }

    /// A message the refresh failed on is the one thing here worth colouring.
    private var isRefreshFailure: Bool {
        refreshMessage != nil && !isRefreshing && hasFailure
    }

    /// One card per fund, not per purchase. Buying the same fund every month is
    /// one position built in instalments, and a list that showed each instalment
    /// buried what the position actually is; the instalments are one tap in.
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionTitle)
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(groups.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.funds)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.funds.opacity(0.16), in: Capsule())

                if let onRefresh {
                    refreshButton(onRefresh)
                }
            }

            if let refreshMessage {
                Text(refreshMessage)
                    .font(.caption)
                    .foregroundStyle(
                        isRefreshFailure ? MonMonTheme.danger : MonMonTheme.textSecondary
                    )
                    .accessibilityIdentifier("refresh-summary")
            }

            ForEach(groups) { group in
                NavigationLink {
                    FundGroupDetailView(
                        route: FundGroupRoute(instrumentID: group.instrumentID)
                    )
                } label: {
                    FundGroupCard(group: group)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fund-group-\(group.id)")
                .accessibilityHint("Opens every position in this \(itemNoun)")
            }
        }
    }

    private var displayedHoldings: [FundHolding] {
        var matching = FundSummary.holdings(holdings, in: instruments, matching: kinds)
        if kinds.contains(.fund) {
            matching += FundSummary.unpriced(holdings: holdings, instruments: instruments)
        }
        return matching
    }
}
