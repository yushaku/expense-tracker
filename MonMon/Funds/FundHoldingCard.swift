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
    /// Every sale out of this lot. What is still held is derived from these, so
    /// a card handed the holding alone would show a closed position as open.
    let sales: [FundSale]
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

            if !isClosed {
                FundProfitLossRow(
                    kind: .unrealized,
                    profitLoss: unrealizedProfitLoss,
                    returnPercent: holding.returnPercent(
                        pricePerUnit: pricePerUnit,
                        sales: sales
                    )
                )
            }

            if hasSales {
                FundProfitLossRow(
                    kind: .realized,
                    profitLoss: realizedProfitLoss,
                    returnPercent: FundSaleSummary.realizedReturnPercent(
                        for: holding,
                        sales: sales
                    )
                )
            }
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
                HStack(spacing: 8) {
                    Text(instrument?.symbol ?? "Unknown instrument")
                        .font(.headline)
                        .lineLimit(1)

                    if isClosed {
                        FundClosedBadge()
                    }
                }

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

    /// The sold column only appears once something has been sold, so an
    /// untouched lot reads exactly as it did before selling existed.
    private var metrics: [FundMetric] {
        var metrics = [
            FundMetric(titleKey: quantityTitle, value: quantityValue),
            FundMetric(
                titleKey: "AVG COST",
                value: VNDCurrency.formatUnitPrice(holding.averageCostPerUnit)
            ),
            FundMetric(
                titleKey: priceTitle,
                value: instrument.map { VNDCurrency.formatUnitPrice($0.currentPricePerUnit) } ?? "—"
            ),
            FundMetric(titleKey: "COST BASIS", value: VNDCurrency.format(costBasis)),
        ]

        if hasSales {
            metrics.append(FundMetric(titleKey: soldTitle, value: soldValue))
            metrics.append(
                FundMetric(
                    titleKey: "PROCEEDS",
                    value: VNDCurrency.format(
                        FundSaleSummary.totalProceeds(
                            of: FundSaleSummary.sales(for: holding, sales: sales)
                        )
                    )
                )
            )
        }

        return metrics
    }

    private var pricePerUnit: Decimal {
        instrument?.currentPricePerUnit ?? .zero
    }

    private var remainingUnits: Decimal {
        holding.remainingUnits(sales: sales)
    }

    private var isClosed: Bool {
        FundSaleSummary.isClosed(holding, sales: sales)
    }

    private var hasSales: Bool {
        FundSaleSummary.hasSales(holding, sales: sales)
    }

    /// What the units still held cost, so it sits beside a market value about
    /// the same units. The original outlay is not lost — it is the sum of this
    /// and the cost of everything sold, which the proceeds column stands over.
    private var costBasis: Decimal {
        holding.remainingCostBasis(sales: sales)
    }

    private var marketValue: Decimal {
        holding.marketValue(pricePerUnit: pricePerUnit, sales: sales)
    }

    private var unrealizedProfitLoss: Decimal {
        holding.unrealizedProfitLoss(pricePerUnit: pricePerUnit, sales: sales)
    }

    private var realizedProfitLoss: Decimal {
        holding.realizedProfitLoss(sales: sales)
    }

    private var soldTitle: String {
        instrument?.kind == .gold ? "SOLD WEIGHT" : "SOLD UNITS"
    }

    private var soldValue: String {
        let sold = FundSaleSummary.unitsSold(for: holding, sales: sales)
        return instrument?.kind == .gold
            ? GoldWeight.label(luong: sold) : UnitQuantity.format(sold)
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

    /// What is still held, not what was bought. The bought figure is still
    /// reachable — it is this plus the sold column beside it — and showing it
    /// here would put a number on the card that no longer describes anything.
    private var quantityValue: String {
        instrument?.kind == .gold
            ? GoldWeight.label(luong: remainingUnits) : UnitQuantity.format(remainingUnits)
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
                    sales: [],
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
                    sales: [],
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
