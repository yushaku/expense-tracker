import SwiftUI

/// One fund, however many times it was bought: total units, what the stack cost
/// per unit on average, and where it stands against today's price.
struct FundGroupCard: View {
    @Environment(\.locale) private var locale

    let group: FundPositionGroup
    /// Passed in rather than read from the clock, so a preview and a test both
    /// get a stable answer for whether the price is stale.
    var asOf: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()
                .overlay(MonMonTheme.border)

            FundMetricGrid(metrics: metrics)

            FundPriceStatusRow(instrument: group.instrument, asOf: asOf)

            if !group.isFullyClosed {
                FundProfitLossRow(
                    kind: .unrealized,
                    profitLoss: group.unrealizedProfitLoss,
                    returnPercent: group.returnPercent
                )
            }

            if group.hasSales {
                FundProfitLossRow(
                    kind: .realized,
                    profitLoss: group.realizedProfitLoss,
                    returnPercent: FundSaleSummary.totalRealizedReturnPercent(
                        of: group.sales,
                        holdings: group.holdings
                    )
                )
            }
        }
        .fundCardBackground()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            FundLogoView(symbol: group.symbol, logoURL: group.instrument?.logoURL)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(group.symbol)
                        .font(.headline)
                        .lineLimit(1)

                    if group.isFullyClosed {
                        FundClosedBadge()
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(VNDCurrency.format(group.marketValue))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("MARKET VALUE")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityHidden(true)
        }
    }

    private var metrics: [FundMetric] {
        [
            FundMetric(titleKey: quantityTitle, value: quantityValue),
            FundMetric(
                titleKey: "AVG COST",
                value: VNDCurrency.formatUnitPrice(group.averageCostPerUnit)
            ),
            FundMetric(
                titleKey: priceTitle,
                value: group.instrument.map { VNDCurrency.formatUnitPrice($0.currentPricePerUnit) }
                    ?? "—"
            ),
            FundMetric(titleKey: "COST BASIS", value: VNDCurrency.format(group.costBasis)),
        ]
    }

    private var priceTitle: String {
        instrumentPolicy.priceMetricTitle
    }

    private var quantityTitle: String {
        instrumentPolicy.quantity.metricTitle
    }

    private var quantityValue: String {
        instrumentPolicy.quantity.summaryValue(storedUnits: group.units)
    }

    private var instrumentPolicy: FundInstrumentPolicy {
        group.instrument?.kind.policy ?? FundInstrumentKind.fund.policy
    }

    /// How many purchases went into the position, and nothing else. The kind
    /// used to lead this line, but "Fund" beside a fund's own ticker said
    /// nothing the ticker had not.
    private var subtitle: String {
        guard group.instrument != nil else {
            let unknown = AppText.string("Unknown instrument", in: locale)
            return "\(unknown) · \(group.positionCountLabel(in: locale))"
        }

        return group.positionCountLabel(in: locale)
    }
}
