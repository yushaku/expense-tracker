import Charts
import SwiftUI

struct AssetGrowthCard: View {
    let points: [AssetHistoryPoint]

    private var currentPoint: AssetHistoryPoint? {
        points.last
    }

    private var change: Decimal {
        guard let first = points.first, let currentPoint else { return .zero }
        return currentPoint.netWorth - first.netWorth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            summary
            chart

            Text("Historical fund and gold values use current prices.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textMuted)
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
        HStack(spacing: 12) {
            Label("NET WORTH TREND", systemImage: "chart.xyaxis.line")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            Text("12M")
                .font(.caption2.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
        }
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(VNDCurrency.format(currentPoint?.netWorth ?? .zero))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer(minLength: 8)

            Label(changeLabel, systemImage: changeSymbolName)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(changeColor)
                .accessibilityLabel(changeAccessibilityLabel)
        }
    }

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Net worth", point.netWorth.chartValue)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [MonMonTheme.accent.opacity(0.28), MonMonTheme.accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Date", point.date),
                y: .value("Net worth", point.netWorth.chartValue)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(MonMonTheme.accent)

            if point.id == currentPoint?.id {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Net worth", point.netWorth.chartValue)
                )
                .symbolSize(52)
                .foregroundStyle(MonMonTheme.accent)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(MonMonTheme.border)
                AxisTick()
                    .foregroundStyle(MonMonTheme.border)
                AxisValueLabel(format: .dateTime.month(.abbreviated))
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
        .frame(height: 210)
        .accessibilityHidden(true)
    }

    private var changeLabel: LocalizedStringKey {
        let amount = change < 0 ? -change : change
        let sign = change > 0 ? "+" : change < 0 ? "−" : ""
        return "\(sign)\(VNDCurrency.format(amount))"
    }

    private var changeSymbolName: String {
        change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "minus"
    }

    private var changeColor: Color {
        if change > 0 {
            MonMonTheme.accent
        } else if change < 0 {
            MonMonTheme.danger
        } else {
            MonMonTheme.textSecondary
        }
    }

    private var changeAccessibilityLabel: LocalizedStringKey {
        switch change {
        case let value where value > 0:
            "Increased by \(VNDCurrency.format(value))"
        case let value where value < 0:
            "Decreased by \(VNDCurrency.format(-value))"
        default:
            "No change"
        }
    }
}

private extension Decimal {
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#if DEBUG
    #Preview("Net worth trend") {
        ScrollView {
            AssetGrowthCard(
                points: [
                    AssetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_704_067_200),
                        netWorth: 420_000_000
                    ),
                    AssetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_712_000_000),
                        netWorth: 465_000_000
                    ),
                    AssetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_719_900_000),
                        netWorth: 448_000_000
                    ),
                    AssetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_727_800_000),
                        netWorth: 512_000_000
                    ),
                ]
            )
            .padding(20)
        }
        .background(MonMonTheme.canvas)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
