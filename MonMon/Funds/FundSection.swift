import SwiftUI

/// The funds half of the Investments screen: what the holdings cost against
/// what they are worth, followed by a card per holding. The screen around it
/// owns the scroll, the running total, and the editor sheet.
struct FundSection: View {
    let holdings: [FundHolding]
    /// The catalogue the holdings are priced from. Passed in rather than
    /// queried here so the section stays a plain view over values.
    let instruments: [FundInstrument]
    let accounts: [CashAccount]
    let onAdd: () -> Void
    let onEdit: (FundHolding) -> Void

    var body: some View {
        if holdings.isEmpty {
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
        FundSummary.unpriced(holdings: holdings, instruments: instruments)
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
            FundSummary.unpricedCostBasis(holdings: holdings, instruments: instruments)
        )
        return "\(count) \(noun) no instrument, so \(cost) of cost is counted as worth nothing. "
            + "Open each one and pick what it is held in."
    }

    private var costBasis: Decimal {
        FundSummary.totalCostBasis(of: holdings)
    }

    private var profitLoss: Decimal {
        FundSummary.totalUnrealizedProfitLoss(of: holdings, instruments: instruments)
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

            Button("Add Holding", systemImage: "plus", action: onAdd)
                .accessibilityIdentifier(InvestmentSegment.funds.addIdentifier)
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
                    onEdit(holding)
                } label: {
                    FundHoldingCard(
                        holding: holding,
                        instrument: instruments.matching(holding),
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
