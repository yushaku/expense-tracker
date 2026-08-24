import SwiftUI

/// One fund, however many times it was bought: total units, what the stack cost
/// per unit on average, and where it stands against today's price.
struct FundGroupCard: View {
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

            FundProfitLossRow(
                profitLoss: group.unrealizedProfitLoss,
                returnPercent: group.returnPercent
            )
        }
        .fundCardBackground()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(group.symbol.prefix(2))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 44, height: 44)
                .background(
                    MonMonTheme.funds.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.symbol)
                    .font(.headline)
                    .lineLimit(1)

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
            FundMetric(title: "UNITS", value: UnitQuantity.format(group.units)),
            FundMetric(
                title: "AVG COST",
                value: VNDCurrency.formatUnitPrice(group.averageCostPerUnit)
            ),
            FundMetric(
                title: priceTitle,
                value: group.instrument.map { VNDCurrency.formatUnitPrice($0.currentPricePerUnit) }
                    ?? "—"
            ),
            FundMetric(title: "COST BASIS", value: VNDCurrency.format(group.costBasis)),
        ]
    }

    private var priceTitle: String {
        group.instrument?.kind == .etf ? "PRICE" : "NAV"
    }

    /// How many purchases went into the position, and nothing else. The kind
    /// used to lead this line, but "Fund" beside a fund's own ticker said
    /// nothing the ticker had not.
    private var subtitle: String {
        guard group.instrument != nil else {
            return "Unknown instrument · \(group.positionCountLabel)"
        }

        return group.positionCountLabel
    }
}
