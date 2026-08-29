import Charts
import SwiftUI

/// Where the results had got to by the end of each day: money in hand, run up
/// day by day over the period on show.
///
/// The line answers a question the totals cannot: whether a month ended level
/// because it was quiet, or because a large expense landed on top of a large
/// income halfway through it.
struct NetTrendCard: View {
    let points: [TransactionNetPoint]

    @State private var selectedDay: Date?

    private var finalNet: Decimal {
        points.last?.net ?? .zero
    }

    private var tint: Color {
        finalNet < 0 ? MonMonTheme.danger : MonMonTheme.gain
    }

    private var selectedPoint: TransactionNetPoint? {
        guard let selectedDay else {
            return nil
        }

        return TrendChartSelection.nearest(
            to: selectedDay,
            in: points,
            date: { $0.day }
        )
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
        .accessibilityIdentifier("report-net-trend")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("RUNNING NET", systemImage: "chart.xyaxis.line")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            Text(netLabel)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }

    private var netLabel: LocalizedStringKey {
        let magnitude = finalNet < 0 ? -finalNet : finalNet
        let sign = finalNet < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Net", point.net.chartValue)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Net", point.net.chartValue)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(tint)
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected day", selectedPoint.day))
                    .foregroundStyle(MonMonTheme.textMuted.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 8) {
                        selectionLabel(selectedPoint)
                    }

                PointMark(
                    x: .value("Selected day", selectedPoint.day),
                    y: .value("Selected net", selectedPoint.net.chartValue)
                )
                .symbolSize(120)
                .foregroundStyle(tint)

                PointMark(
                    x: .value("Selected day", selectedPoint.day),
                    y: .value("Selected net", selectedPoint.net.chartValue)
                )
                .symbolSize(42)
                .foregroundStyle(MonMonTheme.surface)
            }
        }
        // Zero is where the period turns from earning into spending, so the line
        // is read against it rather than against the lowest day drawn.
        .chartYScale(domain: .automatic(includesZero: true))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(MonMonTheme.border)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
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
        .chartXSelection(value: $selectedDay)
        .frame(height: 190)
        .sensoryFeedback(.selection, trigger: selectedPoint?.day)
        .onChange(of: points) {
            selectedDay = nil
        }
        // The figure in the header states where the line ends, which is the
        // only reading of it that survives being read aloud.
        .accessibilityHidden(true)
    }

    private func selectionLabel(_ point: TransactionNetPoint) -> some View {
        Text(VNDCurrency.format(point.net))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(MonMonTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MonMonTheme.field, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
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
