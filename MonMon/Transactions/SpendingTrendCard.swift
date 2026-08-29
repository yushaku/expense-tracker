import Charts
import SwiftUI

/// How the money moved over the period on show: what went out and what came in,
/// one point per day when a month is being read and one per month when a year
/// is.
///
/// The totals above say what the period came to. This says how it got there —
/// whether a month went in one afternoon or a little at a time, and where the
/// income landed against it.
struct SpendingTrendCard: View {
    let unit: SpendingTrendUnit
    let points: [SpendingTrendPoint]

    /// Which lines the owner has put away. Two lines an order of magnitude
    /// apart — a month of small expenses under one salary — flatten each other
    /// against a shared scale, so either can be dropped and the other redrawn
    /// against its own figures.
    ///
    /// The last one on show cannot be put away: an empty chart answers nothing.
    @State private var hiddenKinds: Set<TransactionKind> = []

    private var shownKinds: [TransactionKind] {
        TransactionKind.allCases.filter { !hiddenKinds.contains($0) }
    }

    private func total(of kind: TransactionKind) -> Decimal {
        points.reduce(Decimal.zero) { $0 + amount(of: kind, in: $1) }
    }

    private func amount(of kind: TransactionKind, in point: SpendingTrendPoint) -> Decimal {
        switch kind {
        case .expense:
            point.expense
        case .income:
            point.income
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if points.count < 2 {
                Text("A day or two of records draws no trend yet.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                chart

                average
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
        .accessibilityIdentifier("report-spending-trend")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("SPENDING TREND", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            // Which line is which, and which are drawn. Two directions on one
            // chart cannot be told apart by shape, and the built-in legend can
            // neither be coloured to the hues the rest of the app spends and
            // earns in nor tapped.
            HStack(spacing: 12) {
                swatch(.expense)
                swatch(.income)
            }
        }
    }

    private func swatch(_ kind: TransactionKind) -> some View {
        let isShown = !hiddenKinds.contains(kind)

        return Button {
            toggle(kind)
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(isShown ? tint(of: kind) : MonMonTheme.textMuted.opacity(0.4))
                    .frame(width: 8, height: 8)

                Text(kind.displayName)
                    .font(.caption)
                    .foregroundStyle(isShown ? MonMonTheme.textSecondary : MonMonTheme.textMuted)
                    .strikethrough(!isShown, color: MonMonTheme.textMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // The one line still drawn stays drawn: putting it away would leave an
        // empty chart, which is not a reading of anything.
        .disabled(isShown && shownKinds.count == 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isShown ? .isSelected : [])
        .accessibilityIdentifier("report-spending-trend-\(kind.rawValue)")
    }

    private func toggle(_ kind: TransactionKind) {
        withAnimation(.snappy(duration: 0.28)) {
            if hiddenKinds.contains(kind) {
                hiddenKinds.remove(kind)
            } else if shownKinds.count > 1 {
                hiddenKinds.insert(kind)
            }
        }
    }

    private func tint(of kind: TransactionKind) -> Color {
        switch kind {
        case .expense:
            MonMonTheme.danger
        case .income:
            MonMonTheme.gain
        }
    }

    private var chart: some View {
        Chart {
            ForEach(shownKinds, id: \.self) { kind in
                ForEach(points) { point in
                    LineMark(
                        x: .value("Period", point.start),
                        y: .value("Amount", amount(of: kind, in: point).chartValue),
                        series: .value("Direction", kind.rawValue)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(by: .value("Direction", kind.rawValue))
                }
            }
        }
        .chartForegroundStyleScale(
            domain: TransactionKind.allCases.map(\.rawValue),
            range: TransactionKind.allCases.map(tint(of:))
        )
        .animation(.snappy(duration: 0.28), value: hiddenKinds)
        // Zero is the floor a direction is read against: a quiet day sits on it
        // rather than at the bottom of whatever the busiest day happened to be.
        .chartYScale(domain: .automatic(includesZero: true))
        // The swatches in the header already name the two lines, and they carry
        // the app's own colours.
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(MonMonTheme.border)
                AxisValueLabel(format: axisDateFormat)
                    .foregroundStyle(MonMonTheme.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(MonMonTheme.border)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(VNDCurrency.format(amount))
                    }
                }
                .foregroundStyle(MonMonTheme.textMuted)
            }
        }
        .frame(height: 190)
        // The sentence under the chart states what the two lines average, which
        // is the reading of them that survives being read aloud.
        .accessibilityHidden(true)
    }

    private var axisDateFormat: Date.FormatStyle {
        switch unit {
        case .day:
            .dateTime.day().month(.abbreviated)
        case .month:
            .dateTime.month(.abbreviated)
        }
    }

    private var average: some View {
        Text(averageNotice)
            .font(.footnote)
            .foregroundStyle(MonMonTheme.textSecondary)
    }

    /// What a day or a month of this period came to on average. The busiest one
    /// is what the chart shows; this is what it usually was.
    ///
    /// It names the lines on show and no others, so a line put away is gone
    /// from the card entirely rather than still being spoken about under it.
    private var averageNotice: LocalizedStringKey {
        let count = Decimal(points.count)
        let expense = VNDCurrency.format(total(of: .expense) / count)
        let income = VNDCurrency.format(total(of: .income) / count)

        switch (shownKinds.contains(.expense), shownKinds.contains(.income), unit) {
        case (true, true, .day):
            return "Averaging \(expense) out and \(income) in per day."
        case (true, true, .month):
            return "Averaging \(expense) out and \(income) in per month."
        case (true, false, .day):
            return "Averaging \(expense) out per day."
        case (true, false, .month):
            return "Averaging \(expense) out per month."
        case (false, true, .day):
            return "Averaging \(income) in per day."
        default:
            return "Averaging \(income) in per month."
        }
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the plotted height. Money stays
    /// `Decimal` everywhere it is summed or displayed; only the drawn height
    /// converts, where a rounding error is invisible.
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#if DEBUG
    #Preview("Spending trend") {
        let start = TransactionPeriod.startOfMonth(for: .now)
        let points = (0..<14).map { offset in
            SpendingTrendPoint(
                start: TransactionPeriod.calendar.date(byAdding: .day, value: offset, to: start)
                    ?? start,
                expense: Decimal(offset % 5) * 120_000,
                income: offset == 3 ? 12_000_000 : .zero
            )
        }

        return SpendingTrendCard(unit: .day, points: points)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
