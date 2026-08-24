import SwiftUI

/// One purchase of one fund: the units bought, what they cost, and where that
/// single lot stands today. The list groups these by instrument, so this card is
/// what a group opens into rather than what the list shows.
struct FundHoldingCard: View {
    @Environment(\.locale) private var locale

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

            FundMetricGrid(metrics: metrics)

            FundPriceStatusRow(instrument: instrument, asOf: asOf)

            FundProfitLossRow(
                profitLoss: unrealizedProfitLoss,
                returnPercent: holding.returnPercent(pricePerUnit: pricePerUnit)
            )
        }
        .fundCardBackground()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            // The ticker, not the fund's full name: "VinaCapital VESAF Equity
            // Special Access Fund" wrapped to three lines and pushed the market
            // value off an iPhone's width, while the symbol is what the owner
            // recognises the holding by anyway.
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
                Text(instrument?.symbol ?? "Unknown instrument")
                    .font(.headline)
                    .lineLimit(1)

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

    private var metrics: [FundMetric] {
        [
            FundMetric(title: quantityTitle, value: quantityValue),
            FundMetric(
                title: "AVG COST",
                value: VNDCurrency.formatUnitPrice(holding.averageCostPerUnit)
            ),
            FundMetric(
                title: priceTitle,
                value: instrument.map { VNDCurrency.formatUnitPrice($0.currentPricePerUnit) } ?? "—"
            ),
            FundMetric(title: "COST BASIS", value: VNDCurrency.format(holding.costBasis)),
        ]
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
        switch instrument?.kind {
        case .etf:
            "PRICE"
        case .gold:
            "BUY"
        default:
            "NAV"
        }
    }

    private var quantityTitle: String {
        instrument?.kind == .gold ? "WEIGHT" : "UNITS"
    }

    private var quantityValue: String {
        instrument?.kind == .gold
            ? GoldWeight.label(luong: holding.units) : UnitQuantity.format(holding.units)
    }

    private var subtitle: String {
        let bought = TransactionPeriod.day(holding.boughtOn, in: locale)

        guard let instrument else {
            return "Unknown instrument · \(bought)"
        }

        if let sourceAccountName {
            return "\(instrument.kind.displayName) · \(bought) · from \(sourceAccountName)"
        }

        return "\(instrument.kind.displayName) · \(bought)"
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
