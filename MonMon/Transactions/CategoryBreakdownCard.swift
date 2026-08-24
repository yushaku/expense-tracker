import Charts
import SwiftUI

/// The period's spending or earning split by category: a doughnut, and a row
/// per category below it that opens the transactions behind it.
///
/// The doughnut carries no legend of its own. Every name it would have listed is
/// already in the rows below, and tapping a wedge names it in the middle of the
/// ring, so a third copy only cost the chart its width.
struct CategoryBreakdownCard: View {
    @Binding var kind: TransactionKind

    let slices: [CategoryBreakdownSlice]
    let range: TransactionRange

    /// The wedge the owner tapped, held by id rather than by index so a period
    /// that reorders its categories keeps the same one picked.
    @State private var selectedSliceID: String?

    private static let diameter: CGFloat = 168
    private static let innerRadiusRatio: CGFloat = 0.62

    private var total: Decimal {
        CategoryBreakdown.total(of: slices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if slices.isEmpty {
                emptyState
            } else {
                doughnut
                    .frame(maxWidth: .infinity)

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
                .frame(maxWidth: .infinity, alignment: .leading)

            SegmentedTabs(
                label: "Direction",
                selection: $kind,
                options: TransactionKind.allCases,
                title: \.displayName
            )
            .accessibilityIdentifier("breakdown-kind")
        }
    }

    private var doughnut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.amount.chartValue),
                innerRadius: .ratio(0.62),
                // The tapped wedge stands out of the ring. Every other wedge
                // keeps the smaller radius whether or not one is picked, so the
                // doughnut never resizes the card around it.
                outerRadius: .ratio(isSelected(slice) ? 1 : 0.9),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(CategoryPalette.color(named: slice.colorName))
            .opacity(selectedSliceID == nil || isSelected(slice) ? 1 : 0.3)
        }
        .chartLegend(.hidden)
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay {
            centerLabel
        }
        // The whole square takes the tap, and where in it the tap landed is
        // turned into a wedge below. Charts' own angle selection reported
        // nothing here, and this also gives the hole in the middle a job:
        // clearing the pick.
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { tap in
                    withAnimation(.snappy(duration: 0.28)) {
                        selectSlice(at: tap.location)
                    }
                }
        )
        .animation(.snappy(duration: 0.28), value: selectedSliceID)
        // A picked wedge belongs to the period on show; a new period makes it
        // point at a category that may no longer be there.
        .onChange(of: kind) { _, _ in
            selectedSliceID = nil
        }
        .onChange(of: slices) { _, _ in
            selectedSliceID = nil
        }
        // The rows below state every figure in text, so the wedges add nothing
        // for VoiceOver to read.
        .accessibilityHidden(true)
    }

    /// The hole in the middle carries the period's total until a wedge is
    /// tapped, and then that wedge's name and share, which is the question a tap
    /// on a doughnut is asking.
    @ViewBuilder
    private var centerLabel: some View {
        if let slice = selectedSlice {
            VStack(spacing: 2) {
                Image(systemName: slice.symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CategoryPalette.color(named: slice.colorName))

                Text(slice.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(Percentage.label(of: slice.amount, in: total))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                Text(VNDCurrency.format(slice.amount))
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .padding(.horizontal, 22)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
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
            .transition(.opacity)
        }
    }

    private var selectedSlice: CategoryBreakdownSlice? {
        slices.first { $0.id == selectedSliceID }
    }

    /// Turns a point in the doughnut into the wedge under it: how far round the
    /// ring the tap sits, clockwise from twelve o'clock, is the wedge's share of
    /// the total run up to it.
    private func selectSlice(at location: CGPoint) {
        let radius = Self.diameter / 2
        let across = location.x - radius
        let down = location.y - radius
        let distance = (across * across + down * down).squareRoot()

        // The hole in the middle and anything past the ring clear the pick, so
        // a tap that missed every wedge is never read as choosing one.
        guard distance >= radius * Self.innerRadiusRatio, distance <= radius else {
            selectedSliceID = nil
            return
        }

        var turn = atan2(across, -down) / (2 * .pi)

        if turn < 0 {
            turn += 1
        }

        let tapped = CategoryBreakdown.slice(atTurn: Double(turn), in: slices)

        // Tapping the wedge already picked puts the period's total back.
        selectedSliceID = tapped?.id == selectedSliceID ? nil : tapped?.id
    }

    private func isSelected(_ slice: CategoryBreakdownSlice) -> Bool {
        selectedSlice?.id == slice.id
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
