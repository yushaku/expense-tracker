import Charts
import SwiftUI

/// Which line the account trend draws. One question at a time: what the account
/// took in, what it paid out, or where the two left it.
enum AccountTrendMetric: CaseIterable, Hashable {
    case net
    case income
    case expense

    var title: LocalizedStringKey {
        switch self {
        case .net: "Net"
        case .income: "Income"
        case .expense: "Expenses"
        }
    }

    func amount(in point: SpendingTrendPoint) -> Decimal {
        switch self {
        case .net: point.income - point.expense
        case .income: point.income
        case .expense: point.expense
        }
    }
}

/// How one account moved over the period on show, a day at a time for a month
/// and a month at a time for a year.
///
/// The account card above says where the balance stands now. This says how it
/// got there — which weeks carried the spending, and where the income landed
/// against them.
struct AccountTrendCard: View {
    @Environment(\.appDateFormat) private var dateFormat
    @Environment(\.locale) private var locale

    let points: [SpendingTrendPoint]

    @Binding var metric: AccountTrendMetric
    @Binding var range: TransactionRange

    private var total: Decimal {
        points.reduce(Decimal.zero) { $0 + metric.amount(in: $1) }
    }

    private var tint: Color {
        switch metric {
        case .net: total < 0 ? MonMonTheme.danger : MonMonTheme.gain
        case .income: MonMonTheme.gain
        case .expense: MonMonTheme.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            SegmentedTabs(
                label: "Account trend",
                selection: $metric,
                options: AccountTrendMetric.allCases,
                title: \.title
            )
            .accessibilityIdentifier("account-detail-trend-metric")

            if points.count < 2 {
                Text("A day or two of records draws no trend yet.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("account-detail-trend")
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(range.title(in: locale, dateFormat: dateFormat).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(VNDCurrency.format(total))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 8)

            DateRangeFilterButton(
                range: $range,
                identifierPrefix: "account-detail-trend",
                systemImage: "calendar"
            )
        }
    }

    private var chart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.start),
                y: .value(metric.title, metric.amount(in: point).chartValue)
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
                x: .value("Date", point.start),
                y: .value(metric.title, metric.amount(in: point).chartValue)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .foregroundStyle(tint)
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                    .foregroundStyle(MonMonTheme.border)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(dateFormat.format(date))
                    }
                }
                .foregroundStyle(MonMonTheme.textMuted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
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
        .frame(height: 150)
        // The figure in the header states what the period came to, which is the
        // only reading of the line that survives being read aloud.
        .accessibilityHidden(true)
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
