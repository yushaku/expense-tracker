import SwiftUI

struct ReportHighlightsCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.appDateFormat) private var dateFormat
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
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "Current: \(highlights.periods.current.title(in: locale, dateFormat: dateFormat))"
                )
                Text(
                    "Previous: \(highlights.periods.previous.title(in: locale, dateFormat: dateFormat))"
                )
            }
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)

            if highlights.hasTransactions {
                changeSummary
                Text(
                    "\(VNDCurrency.format(highlights.current)) now · \(VNDCurrency.format(highlights.previous)) previously"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
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
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .appCard()
        .accessibilityIdentifier("report-highlights")
        .appSheet(item: $selectedChange) { change in
            ReportHighlightDetails(change: change, periods: highlights.periods)
        }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
