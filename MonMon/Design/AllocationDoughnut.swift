import Charts
import SwiftUI

/// One wedge of a doughnut, already resolved to the words and colour it is
/// drawn with, so the chart itself stays free of the model it came from.
struct AllocationDoughnutItem: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let tint: Color
    let symbolName: String
}

/// A ring of wedges with its total in the hole and a legend beside it, shared
/// by every card that splits one figure into named parts.
struct AllocationDoughnut: View {
    /// What the legend says each wedge is a share *of*, read out by VoiceOver.
    let context: String
    let items: [AllocationDoughnutItem]

    private var total: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                doughnut
                legend
            }

            VStack(alignment: .leading, spacing: 20) {
                doughnut
                    .frame(maxWidth: .infinity)
                legend
            }
        }
    }

    private var doughnut: some View {
        Chart(items) { item in
            SectorMark(
                angle: .value("Amount", item.amount.doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(item.tint)
        }
        .chartLegend(.hidden)
        .frame(width: 168, height: 168)
        .overlay {
            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)
            }
        }
        // The wedges carry no meaning on their own; the legend below states
        // every figure in text, so the chart itself is skipped by VoiceOver.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                legendRow(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ item: AllocationDoughnutItem) -> some View {
        HStack(spacing: 12) {
            // The symbol repeats what the colour says, so the wedge is
            // identifiable without relying on colour.
            Image(systemName: item.symbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28)
                .background(item.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))

                Text(VNDCurrency.format(item.amount))
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(percentLabel(for: item))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            \(item.name), \(VNDCurrency.format(item.amount)), \(percentLabel(for: item)) of \
            \(context)
            """
        )
    }

    private func percentLabel(for item: AllocationDoughnutItem) -> String {
        let percent = AssetAllocation.percent(of: item.amount, in: total)
        return "\(PercentInput.format(percent))%"
    }
}

extension AssetAllocationSlice.Kind {
    var tint: Color {
        switch self {
        case .cash:
            MonMonTheme.accent
        case .savings:
            MonMonTheme.savings
        case .funds:
            MonMonTheme.funds
        case .gold:
            MonMonTheme.Hue.peach
        case .lent:
            MonMonTheme.lent
        }
    }

    var symbolName: String {
        switch self {
        case .cash:
            "banknote.fill"
        case .savings:
            "building.columns.fill"
        case .funds:
            "chart.line.uptrend.xyaxis"
        case .gold:
            "seal.fill"
        case .lent:
            "tray.and.arrow.up.fill"
        }
    }
}

extension AssetAllocationSlice {
    func doughnutItem(in locale: Locale) -> AllocationDoughnutItem {
        AllocationDoughnutItem(
            id: id,
            name: kind.displayName(in: locale),
            amount: amount,
            tint: kind.tint,
            symbolName: kind.symbolName
        )
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the angle. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn angle is converted,
    /// where a rounding error is invisible.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
