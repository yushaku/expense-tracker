import Charts
import SwiftUI

/// The assets doughnut on the Home screen, with a legend naming every wedge,
/// its amount, and its share.
struct AssetAllocationCard: View {
    let slices: [AssetAllocationSlice]
    let liabilities: Decimal

    private var total: Decimal {
        AssetAllocation.total(of: slices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("ALLOCATION", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

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

            if liabilities > 0 {
                liabilitiesRow
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

    private var doughnut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.amount.doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(slice.kind.tint)
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
            ForEach(slices) { slice in
                legendRow(slice)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ slice: AssetAllocationSlice) -> some View {
        HStack(spacing: 12) {
            // The symbol repeats what the colour says, so the wedge is
            // identifiable without relying on colour.
            Image(systemName: slice.kind.symbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(slice.kind.tint)
                .frame(width: 28, height: 28)
                .background(slice.kind.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(slice.kind.displayName)
                    .font(.subheadline.weight(.semibold))

                Text(VNDCurrency.format(slice.amount))
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(percentLabel(for: slice))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(slice.kind.displayName), \(VNDCurrency.format(slice.amount)), "
                + "\(percentLabel(for: slice)) of assets"
        )
    }

    private func percentLabel(for slice: AssetAllocationSlice) -> String {
        let percent = AssetAllocation.percent(of: slice.amount, in: total)
        return "\(PercentInput.format(percent))%"
    }

    private var liabilitiesRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(width: 28, height: 28)
                .background(MonMonTheme.danger.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Owed")
                    .font(.subheadline.weight(.semibold))

                Text("Borrowed money and overdrawn accounts, already subtracted from total assets")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text("−\(VNDCurrency.format(liabilities))")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.danger)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
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
                    liabilities: 5_200_000
                )

                AssetAllocationCard(
                    slices: [AssetAllocationSlice(kind: .cash, amount: 1_250_000)],
                    liabilities: 0
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
