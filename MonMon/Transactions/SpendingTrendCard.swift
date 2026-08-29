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

    private var totalExpense: Decimal {
        points.reduce(Decimal.zero) { $0 + $1.expense }
    }

    private var totalIncome: Decimal {
        points.reduce(Decimal.zero) { $0 + $1.income }
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

            // Which line is which. Two directions on one chart cannot be told
            // apart by shape, and the built-in legend cannot be coloured to the
            // hues the rest of the app spends and earns in.
            HStack(spacing: 12) {
                swatch(.expense)
                swatch(.income)
            }
        }
    }

    private func swatch(_ kind: TransactionKind) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tint(of: kind))
                .frame(width: 8, height: 8)

            Text(kind.displayName)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
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
            ForEach(points) { point in
                LineMark(
                    x: .value("Period", point.start),
                    y: .value("Amount", point.expense.chartValue),
                    series: .value("Direction", TransactionKind.expense.rawValue)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(by: .value("Direction", TransactionKind.expense.rawValue))

                LineMark(
                    x: .value("Period", point.start),
                    y: .value("Amount", point.income.chartValue),
                    series: .value("Direction", TransactionKind.income.rawValue)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(by: .value("Direction", TransactionKind.income.rawValue))
            }
        }
        .chartForegroundStyleScale(
            domain: TransactionKind.allCases.map(\.rawValue),
            range: TransactionKind.allCases.map(tint(of:))
        )
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
    private var averageNotice: LocalizedStringKey {
        let count = Decimal(points.count)
        let expense = VNDCurrency.format(totalExpense / count)
        let income = VNDCurrency.format(totalIncome / count)

        switch unit {
        case .day:
            return "Averaging \(expense) out and \(income) in per day."
        case .month:
            return "Averaging \(expense) out and \(income) in per month."
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
