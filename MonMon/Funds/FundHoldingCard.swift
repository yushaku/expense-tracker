import SwiftUI

struct FundHoldingCard: View {
    let holding: FundHolding
    let sourceAccountName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
                .overlay(MonMonTheme.border)
            position
            profitLossRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(holding.symbol.prefix(2))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 44, height: 44)
                .background(
                    MonMonTheme.funds.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(holding.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(VNDCurrency.format(holding.marketValue))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("MARKET VALUE")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var position: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                positionColumns
            }

            VStack(alignment: .leading, spacing: 12) {
                positionColumns
            }
        }
    }

    @ViewBuilder
    private var positionColumns: some View {
        detail(title: "UNITS", value: UnitQuantity.format(holding.units))
        detail(
            title: "AVG COST",
            value: VNDCurrency.formatUnitPrice(holding.averageCostPerUnit)
        )
        detail(
            title: "NAV",
            value: VNDCurrency.formatUnitPrice(holding.currentNAVPerUnit)
        )
        detail(title: "NAV AS OF", value: navDescription)
        detail(title: "COST BASIS", value: VNDCurrency.format(holding.costBasis))
    }

    /// Profit and loss never rests on colour alone: the arrow and the explicit
    /// sign carry the meaning, and the tint only reinforces it.
    private var profitLossRow: some View {
        HStack(spacing: 8) {
            Image(systemName: isGain ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)

            Text(profitLossDescription)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(profitLossTitle)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .foregroundStyle(isGain ? MonMonTheme.gain : MonMonTheme.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            (isGain ? MonMonTheme.gain : MonMonTheme.danger).opacity(0.14),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func detail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isGain: Bool {
        holding.unrealizedProfitLoss >= 0
    }

    private var profitLossTitle: String {
        isGain ? "UNREALIZED GAIN" : "UNREALIZED LOSS"
    }

    private var profitLossDescription: String {
        let sign = isGain ? "+" : "−"
        let amount = VNDCurrency.format(abs(holding.unrealizedProfitLoss))
        let percent = PercentInput.format(abs(holding.returnPercent))
        return "\(sign)\(amount) (\(sign)\(percent)%)"
    }

    private var subtitle: String {
        if let sourceAccountName {
            "\(holding.symbol) · \(holding.kind.displayName) · from \(sourceAccountName)"
        } else {
            "\(holding.symbol) · \(holding.kind.displayName)"
        }
    }

    private var navDescription: String {
        holding.navAsOf.formatted(date: .abbreviated, time: .omitted)
    }
}

#if DEBUG
    #Preview("Holding cards") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                FundHoldingCard(
                    holding: .preview(
                        name: "VinaCapital VESAF",
                        symbol: "VESAF",
                        kind: .fund,
                        units: Decimal(string: "1234.5678") ?? 0,
                        averageCostPerUnit: 24_500,
                        currentNAVPerUnit: Decimal(string: "27431.28") ?? 0
                    ),
                    sourceAccountName: "Techcombank"
                )

                FundHoldingCard(
                    holding: .preview(
                        name: "Diamond ETF",
                        symbol: "FUEVFVND",
                        kind: .etf,
                        units: 2_000,
                        averageCostPerUnit: 32_100,
                        currentNAVPerUnit: 29_850
                    ),
                    sourceAccountName: nil
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
