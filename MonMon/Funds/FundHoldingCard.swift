import SwiftUI

struct FundHoldingCard: View {
    let holding: FundHolding
    /// The instrument this position is held in, or `nil` when nothing in the
    /// catalogue matches. Joins are resolved in Swift, so a dangling
    /// `instrumentID` is representable and the card has to say so rather than
    /// quietly rendering a zero.
    let instrument: FundInstrument?
    let sourceAccountName: String?
    /// Passed in rather than read from the clock, so a preview and a test both
    /// get a stable answer for whether the price is stale.
    var asOf: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
                .overlay(MonMonTheme.border)
            position
            priceRow
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
            Text((instrument?.symbol ?? "??").prefix(2))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 44, height: 44)
                .background(
                    MonMonTheme.funds.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(instrument?.name ?? "Unknown instrument")
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(VNDCurrency.format(marketValue))
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
            title: priceTitle,
            value: instrument.map { VNDCurrency.formatUnitPrice($0.currentPricePerUnit) } ?? "—"
        )
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

    /// Where the price came from and when it is from. A stale price says so in
    /// words and carries a symbol; colour only reinforces it.
    @ViewBuilder
    private var priceRow: some View {
        HStack(spacing: 7) {
            Image(systemName: priceSymbol)
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)

            Text(priceDescription)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)
        }
        .foregroundStyle(isStale ? MonMonTheme.danger : MonMonTheme.textSecondary)
        .accessibilityIdentifier("quote-status")
    }

    private var pricePerUnit: Decimal {
        instrument?.currentPricePerUnit ?? .zero
    }

    private var marketValue: Decimal {
        holding.marketValue(pricePerUnit: pricePerUnit)
    }

    private var unrealizedProfitLoss: Decimal {
        holding.unrealizedProfitLoss(pricePerUnit: pricePerUnit)
    }

    private var priceTitle: String {
        instrument?.kind == .etf ? "PRICE" : "NAV"
    }

    private var isStale: Bool {
        guard let instrument, instrument.autoQuoteEnabled else {
            return false
        }

        return TradingCalendar.isStale(
            priceAsOf: instrument.priceAsOf,
            kind: instrument.kind,
            asOf: asOf
        )
    }

    private var priceSymbol: String {
        if instrument == nil {
            return "questionmark.circle"
        }
        return isStale ? "exclamationmark.circle.fill" : "clock"
    }

    private var priceDescription: String {
        guard let instrument else {
            return "Instrument missing — value cannot be worked out"
        }

        let day = instrument.priceAsOf.formatted(date: .abbreviated, time: .omitted)
        let base = "\(instrument.priceLabel) \(day) · \(instrument.source.displayName)"
        return isStale ? "\(base) · Stale" : base
    }

    private var isGain: Bool {
        unrealizedProfitLoss >= 0
    }

    private var profitLossTitle: String {
        isGain ? "UNREALIZED GAIN" : "UNREALIZED LOSS"
    }

    private var profitLossDescription: String {
        let sign = isGain ? "+" : "−"
        let amount = VNDCurrency.format(abs(unrealizedProfitLoss))
        let percent = PercentInput.format(abs(holding.returnPercent(pricePerUnit: pricePerUnit)))
        return "\(sign)\(amount) (\(sign)\(percent)%)"
    }

    private var subtitle: String {
        guard let instrument else {
            return "Unknown instrument"
        }

        if let sourceAccountName {
            return
                "\(instrument.symbol) · \(instrument.kind.displayName) · from \(sourceAccountName)"
        }
        return "\(instrument.symbol) · \(instrument.kind.displayName)"
    }
}

#if DEBUG
    #Preview("Holding cards") {
        let vesaf = FundInstrument.preview(
            name: "VinaCapital VESAF",
            symbol: "VESAF",
            kind: .fund,
            currentPricePerUnit: Decimal(string: "27431.28") ?? 0,
            source: .fmarket
        )
        let diamond = FundInstrument.preview(
            name: "Diamond ETF",
            symbol: "FUEVFVND",
            kind: .etf,
            currentPricePerUnit: 29_850,
            source: .vndirect
        )

        return ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                FundHoldingCard(
                    holding: .preview(
                        instrument: vesaf,
                        units: Decimal(string: "1234.5678") ?? 0,
                        averageCostPerUnit: 24_500
                    ),
                    instrument: vesaf,
                    sourceAccountName: "Techcombank",
                    asOf: vesaf.priceAsOf
                )

                FundHoldingCard(
                    holding: .preview(
                        instrument: diamond,
                        units: 2_000,
                        averageCostPerUnit: 32_100
                    ),
                    instrument: diamond,
                    sourceAccountName: nil,
                    asOf: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 20)
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
