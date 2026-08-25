import Charts
import SwiftUI

/// What each month of the results took in and paid out, side by side.
///
/// The report's other cards say what a period came to. This one says how it got
/// there: a month that looks calm as one figure often is not once the two
/// directions are drawn apart.
struct MonthlyFlowCard: View {
    @Environment(\.locale) private var locale

    let months: [TransactionMonthFlow]

    private static let monthTemplate = Date.FormatStyle().month(.abbreviated)

    /// Two bars a month crowd a phone once a year is on show, so the card keeps
    /// the most recent run rather than shrinking every bar to a hairline.
    private static let visibleMonths = 12

    private var visible: [TransactionMonthFlow] {
        Array(months.suffix(Self.visibleMonths))
    }

    private var busiest: Decimal {
        visible.map { max($0.income, $0.expense) }.max() ?? .zero
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if visible.isEmpty {
                Text("Nothing to chart yet.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                chart
                legend
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
        .accessibilityIdentifier("report-monthly-flow")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("MONTH BY MONTH", systemImage: "chart.bar.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            if visible.count > 1 {
                Text("\(visible.count) months")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
            }
        }
    }

    private var chart: some View {
        Chart(visible) { month in
            BarMark(
                x: .value("Month", label(for: month.month)),
                y: .value("Amount", month.income.chartValue)
            )
            .position(by: .value("Direction", "in"))
            .cornerRadius(4)
            .foregroundStyle(MonMonTheme.gain)

            BarMark(
                x: .value("Month", label(for: month.month)),
                y: .value("Amount", month.expense.chartValue)
            )
            .position(by: .value("Direction", "out"))
            .cornerRadius(4)
            .foregroundStyle(MonMonTheme.danger)
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
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
        .frame(height: 200)
        // The rows below the chart state the same figures in words, so the bars
        // add nothing for VoiceOver to read.
        .accessibilityHidden(true)
    }

    /// Both directions named once, under the chart, since the bars themselves
    /// carry no labels.
    private var legend: some View {
        HStack(spacing: 18) {
            legendEntry(.income, tint: MonMonTheme.gain, total: totalIncome)
            legendEntry(.expense, tint: MonMonTheme.danger, total: totalExpense)

            Spacer(minLength: 0)
        }
    }

    private func legendEntry(
        _ kind: TransactionKind,
        tint: Color,
        total: Decimal
    ) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var totalIncome: Decimal {
        visible.reduce(Decimal.zero) { $0 + $1.income }
    }

    private var totalExpense: Decimal {
        visible.reduce(Decimal.zero) { $0 + $1.expense }
    }

    /// Bars are grouped by a written month rather than by date, so twelve of
    /// them stay evenly spaced whatever the months underneath are worth. The
    /// year joins the label each January, which is where a run of months reads
    /// as having turned over.
    private func label(for month: Date) -> String {
        let name = TransactionPeriod.format(Self.monthTemplate, in: locale).format(month)

        guard TransactionPeriod.calendar.component(.month, from: month) == 1 else {
            return name
        }

        let year = TransactionPeriod.calendar.component(.year, from: month)

        return "\(name) '\(String(year % 100))"
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the bar height. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn height converts,
    /// where a rounding error is invisible.
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
