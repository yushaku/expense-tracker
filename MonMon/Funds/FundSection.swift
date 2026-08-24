import SwiftUI

/// The funds half of the Investments screen: what the holdings cost against
/// what they are worth, followed by a card per holding. The screen around it
/// owns the scroll, the running total, and the editor sheet.
struct FundSection: View {
    let holdings: [FundHolding]
    /// The catalogue the holdings are priced from. Passed in rather than
    /// queried here so the section stays a plain view over values.
    let instruments: [FundInstrument]
    let kinds: [FundInstrumentKind]
    let sectionTitle: String
    let itemName: String
    let emptyTitle: String
    let emptyDescription: String
    let emptySystemImage: String
    let addTitle: String
    let addIdentifier: String
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

    private var unpricedDescription: String {
        let count = unpriced.count
        let noun = count == 1 ? "position has" : "positions have"
        let cost = VNDCurrency.format(
            FundSummary.unpricedCostBasis(holdings: displayedHoldings, instruments: instruments)
        )
        return "\(count) \(noun) no instrument, so \(cost) of cost is counted as worth nothing. "
            + "Open each one and pick what it is held in."
    }

    private var costBasis: Decimal {
        FundSummary.totalCostBasis(of: displayedHoldings)
    }

    private var profitLoss: Decimal {
        FundSummary.totalUnrealizedProfitLoss(
            of: displayedHoldings,
            instruments: instruments
        )
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

    private var groups: [FundPositionGroup] {
        FundSummary.groups(holdings: displayedHoldings, instruments: instruments)
    }

    /// Counts both, because they answer different questions: how many funds are
    /// held, and how many purchases went into them.
    private var holdingCountLabel: String {
        switch displayedHoldings.count {
        case 0:
            return "Ready for your first holding"
        case 1:
            return "Across 1 \(itemName) · 1 position"
        default:
            let items = groups.count == 1 ? "1 \(itemName)" : "\(groups.count) \(itemName)s"
            return "Across \(items) · \(displayedHoldings.count) positions"
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
            }

            ForEach(groups) { group in
                NavigationLink(value: FundGroupRoute(instrumentID: group.instrumentID)) {
                    FundGroupCard(group: group)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fund-group-\(group.id)")
                .accessibilityHint("Opens every position in this \(itemName)")
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
