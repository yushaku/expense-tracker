import Charts
import SwiftUI

/// Separate assets and liabilities doughnuts on the Home screen, each with a
/// legend naming every wedge, its amount, and its share.
struct AssetAllocationCard: View {
    let slices: [AssetAllocationSlice]
    let liabilities: [LiabilityAllocationSlice]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("ALLOCATION", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            if !slices.isEmpty {
                AllocationDoughnut(
                    title: "ASSETS",
                    items: slices.map(\.doughnutItem)
                )
            }

            if !slices.isEmpty, !liabilities.isEmpty {
                Divider()
                    .overlay(MonMonTheme.border)
            }

            if !liabilities.isEmpty {
                AllocationDoughnut(
                    title: "LIABILITIES",
                    items: liabilities.map(\.doughnutItem)
                )
            }
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
    }
}

private struct AllocationDoughnutItem: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let tint: Color
    let symbolName: String
}

private struct AllocationDoughnut: View {
    let title: String
    let items: [AllocationDoughnutItem]

    private var total: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textPrimary)

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
            "\(item.name), \(VNDCurrency.format(item.amount)), "
                + "\(percentLabel(for: item)) of \(title.lowercased())"
        )
    }

    private func percentLabel(for item: AllocationDoughnutItem) -> String {
        let percent = AssetAllocation.percent(of: item.amount, in: total)
        return "\(PercentInput.format(percent))%"
    }
}

private extension AssetAllocationSlice {
    var doughnutItem: AllocationDoughnutItem {
        AllocationDoughnutItem(
            id: id,
            name: kind.displayName,
            amount: amount,
            tint: kind.tint,
            symbolName: kind.symbolName
        )
    }
}

private extension LiabilityAllocationSlice {
    var doughnutItem: AllocationDoughnutItem {
        AllocationDoughnutItem(
            id: id,
            name: kind.displayName,
            amount: amount,
            tint: kind.tint,
            symbolName: kind.symbolName
        )
    }
}

private extension LiabilityAllocationSlice.Kind {
    var tint: Color {
        switch self {
        case .borrowed:
            MonMonTheme.danger
        case .overdraft:
            MonMonTheme.Hue.peach
        }
    }

    var symbolName: String {
        switch self {
        case .borrowed:
            "creditcard.fill"
        case .overdraft:
            "exclamationmark.triangle.fill"
        }
    }
}

private extension AssetAllocationSlice.Kind {
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

private extension Decimal {
    /// Swift Charts takes a `Double` for the angle. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn angle is converted,
    /// where a rounding error is invisible.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#if DEBUG
    #Preview("Allocation") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                AssetAllocationCard(
                    slices: [
                        AssetAllocationSlice(kind: .savings, amount: 350_000_000),
                        AssetAllocationSlice(kind: .gold, amount: 147_000_000),
                        AssetAllocationSlice(kind: .funds, amount: 93_565_000),
                        AssetAllocationSlice(kind: .cash, amount: 49_150_000),
                    ],
                    liabilities: [
                        LiabilityAllocationSlice(kind: .borrowed, amount: 20_000_000),
                        LiabilityAllocationSlice(kind: .overdraft, amount: 5_200_000),
                    ]
                )

                AssetAllocationCard(
                    slices: [AssetAllocationSlice(kind: .cash, amount: 1_250_000)],
                    liabilities: []
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
