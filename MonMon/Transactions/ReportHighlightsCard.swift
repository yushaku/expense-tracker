import SwiftUI

struct ReportHighlightsCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.appDateFormat) private var dateFormat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let highlights: ReportHighlights
    @State private var selectedChange: ReportCategoryChange?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Highlights", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(MonMonTheme.accent)
            Text(
                highlights.kind == .income
                    ? "Income compared with previous period"
                    : "Spending compared with previous period"
            )
            .font(.subheadline.weight(.semibold))
            comparisonPeriods

            if highlights.hasTransactions {
                changeSummary
                ForEach(highlights.changes) { change in
                    Button {
                        selectedChange = change
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName: change.delta > 0 ? "arrow.up.right" : "arrow.down.right"
                            )
                            .foregroundStyle(changeColor(change.delta))
                            if let name = change.name { Text(name) } else { Text("Uncategorized") }
                            Spacer(minLength: 4)
                            Text(signed(change.delta))
                                .monospacedDigit()
                                .foregroundStyle(changeColor(change.delta))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(MonMonTheme.textMuted)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows matching transactions in both periods")
                }
            } else {
                Text("No matching transactions in either period.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            if let rhythm = highlights.spendingRhythm {
                Divider().overlay(MonMonTheme.border)
                spendingRhythm(rhythm)
            }
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .appCard()
        .accessibilityIdentifier("report-highlights")
        .appSheet(item: $selectedChange) { change in
            ReportHighlightDetails(change: change, periods: highlights.periods)
        }
    }

    private var comparisonPeriods: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            ReportPeriodBadge(
                title: "Current period", range: highlights.periods.current,
                amount: highlights.current, isCurrent: true)
            ReportPeriodBadge(
                title: "Previous period", range: highlights.periods.previous,
                amount: highlights.previous, isCurrent: false)
        }
    }

    private func spendingRhythm(_ rhythm: ReportSpendingRhythm) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Spending rhythm", systemImage: "chart.bar.xaxis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)
            Group {
                if rhythm.period == highlights.periods.current {
                    Label("Current period · \(rhythm.dayCount) days", systemImage: "calendar")
                } else {
                    Label(
                        rhythm.period.title(in: locale, dateFormat: dateFormat),
                        systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
            rhythmMetric("Average per day", value: VNDCurrency.format(rhythm.averagePerDay))
            rhythmMetric("Expense count", value: rhythm.count.formatted(.number.locale(locale)))
            if let average = rhythm.averagePerExpense {
                rhythmMetric("Average per expense", value: VNDCurrency.format(average))
            } else {
                Text("No expenses recorded in this period.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            Text(
                "Across \(rhythm.dayCount) calendar days, including days without recorded expenses."
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityIdentifier("report-spending-rhythm")
    }

    private func rhythmMetric(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(MonMonTheme.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private var changeSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if highlights.delta == 0 {
                    Text("Unchanged from previous period")
                } else if highlights.delta > 0 {
                    Text("Up \(VNDCurrency.format(highlights.delta))")
                } else {
                    Text("Down \(VNDCurrency.format(-highlights.delta))")
                }
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(changeColor(highlights.delta))
            if let percentage = highlights.percentageChange, highlights.delta != 0 {
                Text(percentage, format: .percent.precision(.fractionLength(1)))
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private func changeColor(_ delta: Decimal) -> Color {
        guard delta != 0 else { return MonMonTheme.textSecondary }
        let increased = delta > 0
        return increased == (highlights.kind == .income)
            ? MonMonTheme.accent : MonMonTheme.Hue.peach
    }

    private func signed(_ amount: Decimal) -> String {
        "\(amount > 0 ? "+" : "−")\(VNDCurrency.format(abs(amount)))"
    }
}

/// Separate day numbers from their shared month so the comparison reads at a
/// glance. Cross-month ranges retain full dates and the owner's date format.
private struct ReportPeriodBadge: View {
    @Environment(\.locale) private var locale
    @Environment(\.appDateFormat) private var dateFormat
    let title: LocalizedStringKey
    let range: TransactionRange
    let amount: Decimal
    let isCurrent: Bool

    private var sharesMonth: Bool {
        TransactionPeriod.calendar.isDate(
            range.start, equalTo: range.lastDay, toGranularity: .month)
    }

    private var days: String {
        let style = TransactionPeriod.format(Date.FormatStyle().day(), in: locale)
        let start = style.format(range.start)
        return range.start == range.lastDay ? start : "\(start)–\(style.format(range.lastDay))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCurrent ? MonMonTheme.accent : MonMonTheme.textSecondary)
            Group {
                if sharesMonth {
                    Text(days)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text(
                        TransactionPeriod.format(
                            Date.FormatStyle().month(.abbreviated).year(), in: locale
                        ).format(range.start)
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    Text(dateFormat.format(range.start))
                    Text("→ \(dateFormat.format(range.lastDay))")
                }
            }
            .font(.subheadline.weight(.medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(range.title(in: locale, dateFormat: dateFormat))
            Text(VNDCurrency.format(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isCurrent ? MonMonTheme.accent.opacity(0.08) : MonMonTheme.canvas,
            in: .rect(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrent ? MonMonTheme.accent.opacity(0.25) : MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReportHighlightDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.appDateFormat) private var dateFormat
    let change: ReportCategoryChange
    let periods: ReportComparisonPeriods

    var body: some View {
        NavigationStack {
            List {
                Section {
                    rows(change.currentTransactions)
                } header: {
                    Text("Current: \(periods.current.title(in: locale, dateFormat: dateFormat))")
                }
                Section {
                    rows(change.previousTransactions)
                } header: {
                    Text("Previous: \(periods.previous.title(in: locale, dateFormat: dateFormat))")
                }
            }
            .scrollContentBackground(.hidden)
            .background(MonMonTheme.canvas)
            .foregroundStyle(MonMonTheme.textPrimary)
            .navigationTitle(change.name ?? AppText.string("Uncategorized", in: locale))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(MonMonTheme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ transactions: [MoneyTransaction]) -> some View {
        if transactions.isEmpty {
            Text("No matching transactions")
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        ForEach(transactions.sorted { $0.occurredAt > $1.occurredAt }) { transaction in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if !transaction.note.isEmpty { Text(transaction.note) }
                    Text(dateFormat.format(transaction.occurredAt))
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                Spacer()
                Text(VNDCurrency.format(transaction.amount)).monospacedDigit()
            }
            .listRowBackground(MonMonTheme.surface)
            .accessibilityElement(children: .combine)
        }
    }
}
