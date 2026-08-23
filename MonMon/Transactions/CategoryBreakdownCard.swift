import Charts
import SwiftUI

/// The period's spending or earning split by category: a doughnut with a legend
/// beside it, and a row per category below that opens the transactions behind
/// it.
struct CategoryBreakdownCard: View {
    @Binding var kind: TransactionKind

    let slices: [CategoryBreakdownSlice]
    let range: TransactionRange

    private var total: Decimal {
        CategoryBreakdown.total(of: slices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if slices.isEmpty {
                emptyState
            } else {
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

                Divider()
                    .overlay(MonMonTheme.border)

                categoryRows
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("BY CATEGORY", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Picker("Direction", selection: $kind) {
                ForEach(TransactionKind.allCases, id: \.rawValue) {
                    Text($0.displayName)
                        .tag($0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("breakdown-kind")
        }
    }

    private var doughnut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.amount.chartValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(CategoryPalette.color(named: slice.colorName))
        }
        .chartLegend(.hidden)
        .frame(width: 168, height: 168)
        .overlay {
            VStack(spacing: 2) {
                Text(kind.displayName.uppercased())
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
        // The rows below state every figure in text, so the wedges add nothing
        // for VoiceOver to read.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slices) { slice in
                HStack(spacing: 10) {
                    Image(systemName: slice.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(CategoryPalette.color(named: slice.colorName))
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    Text(slice.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(Percentage.label(of: slice.amount, in: total))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var categoryRows: some View {
        VStack(spacing: 10) {
            ForEach(slices) { slice in
                NavigationLink(
                    value: CategoryPeriod(
                        categoryID: slice.categoryID,
                        kind: kind,
                        range: range
                    )
                ) {
                    row(slice)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("breakdown-\(slice.id)")
                .accessibilityHint("Opens this category's transactions.")
            }
        }
    }

    private func row(_ slice: CategoryBreakdownSlice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: slice.symbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(CategoryPalette.color(named: slice.colorName))
                .frame(width: 34, height: 34)
                .background(
                    CategoryPalette.color(named: slice.colorName).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(slice.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(countLabel(slice))
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(VNDCurrency.format(slice.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(Percentage.label(of: slice.amount, in: total))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(slice.name), \(VNDCurrency.format(slice.amount)), "
                + "\(Percentage.label(of: slice.amount, in: total)), \(countLabel(slice))"
        )
    }

    private func countLabel(_ slice: CategoryBreakdownSlice) -> String {
        slice.count == 1 ? "1 transaction" : "\(slice.count) transactions"
    }

    private var emptyState: some View {
        Text("No \(kind.displayName.lowercased()) recorded \(range.phrase).")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the angle. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn angle converts,
    /// where a rounding error is invisible.
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
