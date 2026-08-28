import Charts
import SwiftUI

/// Income bridged through the largest spending categories to what remains.
/// The chart runs vertically so category names stay readable on a phone while
/// each horizontal bar shows the balance before and after that subtraction.
struct CategoryWaterfallCard: View {
    @Environment(\.locale) private var locale

    let summary: CategoryWaterfallSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            chart

            Divider()
                .overlay(MonMonTheme.border)

            totals
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
        .accessibilityIdentifier("category-waterfall")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label("CATEGORY WATERFALL", systemImage: "chart.bar.xaxis")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(savingsRateLabel)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(netTint)

                Text("SAVINGS RATE")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart {
            RuleMark(x: .value(AppText.string("Zero balance", in: locale), 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(MonMonTheme.textMuted.opacity(0.55))
                .accessibilityHidden(true)

            ForEach(summary.steps) { step in
                BarMark(
                    xStart: .value(
                        AppText.string("Lower balance", in: locale),
                        lowerBound(of: step)
                    ),
                    xEnd: .value(
                        AppText.string("Upper balance", in: locale),
                        upperBound(of: step)
                    ),
                    y: .value(AppText.string("Cash-flow step", in: locale), step.id)
                )
                .cornerRadius(5)
                .foregroundStyle(tint(for: step))
                .accessibilityLabel(displayName(for: step))
                .accessibilityValue(accessibilityValue(for: step))
            }
        }
        .chartXScale(domain: .automatic(includesZero: true))
        .chartYScale(domain: Array(summary.steps.map(\.id).reversed()))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
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
        .chartYAxis {
            AxisMarks(position: .leading, values: summary.steps.map(\.id)) { value in
                AxisValueLabel {
                    if let id = value.as(String.self),
                        let step = summary.steps.first(where: { $0.id == id })
                    {
                        Text(displayName(for: step))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .frame(height: max(210, CGFloat(summary.steps.count) * 38))
    }

    private var totals: some View {
        HStack(spacing: 10) {
            total("INCOME", amount: summary.income, tint: MonMonTheme.gain)
            total("EXPENSES", amount: summary.totalExpense, tint: MonMonTheme.danger)
            total("NET SAVINGS", amount: summary.netSavings, tint: netTint)
        }
    }

    private func total(_ title: LocalizedStringKey, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(MonMonTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(VNDCurrency.format(amount))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var savingsRateLabel: String {
        guard let rate = summary.savingsRate else {
            return "—"
        }

        return "\(PercentInput.format(rate))%"
    }

    private var netTint: Color {
        summary.netSavings < 0 ? MonMonTheme.danger : MonMonTheme.gain
    }

    private func lowerBound(of step: CategoryWaterfallStep) -> Double {
        chartValue(min(step.start, step.end))
    }

    private func upperBound(of step: CategoryWaterfallStep) -> Double {
        chartValue(max(step.start, step.end))
    }

    private func tint(for step: CategoryWaterfallStep) -> Color {
        switch step.kind {
        case .income:
            MonMonTheme.gain
        case .expense:
            CategoryPalette.color(named: step.colorName ?? CategoryPalette.defaultColorName)
        case .other:
            MonMonTheme.textMuted
        case .netSavings:
            netTint
        }
    }

    private func displayName(for step: CategoryWaterfallStep) -> String {
        switch step.kind {
        case .income:
            AppText.string("Income", in: locale)
        case .other:
            AppText.string("Other", in: locale)
        case .netSavings:
            AppText.string("Net savings", in: locale)
        case .expense:
            step.name
        }
    }

    private func accessibilityValue(for step: CategoryWaterfallStep) -> String {
        switch step.kind {
        case .income:
            VNDCurrency.format(step.amount)
        case .expense, .other:
            AppText.string(
                "Subtract \(VNDCurrency.format(step.amount)), remaining \(VNDCurrency.format(step.end))",
                in: locale
            )
        case .netSavings:
            "\(VNDCurrency.format(step.amount)), \(savingsRateLabel)"
        }
    }

    private func chartValue(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

#if DEBUG
    #Preview("Category waterfall · surplus") {
        CategoryWaterfallCard(summary: .previewSurplus)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Category waterfall · deficit") {
        CategoryWaterfallCard(summary: .previewDeficit)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Category waterfall · no income") {
        CategoryWaterfallCard(summary: .previewNoIncome)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    private extension CategoryWaterfallSummary {
        static let previewSurplus = preview(
            income: 24_000_000,
            expenses: [
                ("Housing", 7_000_000, "blue"),
                ("Food", 3_400_000, "peach"),
                ("Transport", 1_800_000, "mauve"),
                ("Shopping", 1_200_000, "pink"),
            ]
        )

        static let previewDeficit = preview(
            income: 8_000_000,
            expenses: [
                ("Housing", 6_000_000, "blue"),
                ("Food", 3_000_000, "peach"),
                ("Transport", 1_000_000, "mauve"),
            ]
        )

        static let previewNoIncome = preview(
            income: 0,
            expenses: [
                ("Food", 3_000_000, "peach"),
                ("Transport", 1_000_000, "mauve"),
            ]
        )

        static func preview(
            income: Decimal,
            expenses: [(String, Decimal, String)]
        ) -> CategoryWaterfallSummary {
            var balance = income
            var steps = [
                CategoryWaterfallStep(
                    id: "income",
                    name: "Income",
                    kind: .income,
                    amount: income,
                    start: 0,
                    end: income,
                    colorName: nil
                )
            ]

            for (index, expense) in expenses.enumerated() {
                let remaining = balance - expense.1
                steps.append(
                    CategoryWaterfallStep(
                        id: "preview-\(index)",
                        name: expense.0,
                        kind: .expense,
                        amount: expense.1,
                        start: balance,
                        end: remaining,
                        colorName: expense.2
                    )
                )
                balance = remaining
            }

            steps.append(
                CategoryWaterfallStep(
                    id: "net-savings",
                    name: "Net savings",
                    kind: .netSavings,
                    amount: balance,
                    start: 0,
                    end: balance,
                    colorName: nil
                )
            )

            return CategoryWaterfallSummary(
                income: income,
                totalExpense: income - balance,
                netSavings: balance,
                savingsRate: income > 0 ? Percentage.share(of: balance, in: income) : nil,
                steps: steps
            )
        }
    }
#endif
