import SwiftUI

struct GoalCard: View {
    let goal: FinancialGoal
    let jarName: String
    let asOf: Date

    private var snapshot: GoalProgressSnapshot {
        GoalProgress.snapshot(goal: goal, asOf: asOf)
    }

    private var tint: Color {
        CategoryPalette.color(named: goal.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            progressSection
            amountMetrics
            forecastSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: CategoryPalette.symbolName(goal.symbolName))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(goal.kind.title)
                    Text("·")
                        .accessibilityHidden(true)
                    Text(jarName)
                }
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            if snapshot.isComplete {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Complete")
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: snapshot.progress)
                .tint(tint)
                .accessibilityLabel("Goal progress")
                .accessibilityValue(
                    Percentage.label(of: goal.earmarkedAmount, in: goal.targetAmount))

            HStack {
                Text("Earmarked")
                Spacer()
                Text("Target")
            }
            .font(.caption2)
            .foregroundStyle(MonMonTheme.textMuted)
        }
    }

    private var amountMetrics: some View {
        HStack(alignment: .top, spacing: 12) {
            metric("Earmarked", amount: goal.earmarkedAmount)
            metric("Remaining", amount: snapshot.remainingAmount)
            metric("Target", amount: goal.targetAmount)
        }
    }

    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(MonMonTheme.border)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Required monthly")
                        .font(.caption2)
                        .foregroundStyle(MonMonTheme.textMuted)

                    Text(VNDCurrency.format(snapshot.requiredMonthlyContribution))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Forecast")
                        .font(.caption2)
                        .foregroundStyle(MonMonTheme.textMuted)

                    if let date = snapshot.forecastCompletionDate {
                        Text(date, format: .dateTime.month().year())
                            .font(.caption.weight(.semibold))
                    } else {
                        Text("No monthly plan")
                            .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private func metric(_ title: LocalizedStringKey, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MonMonTheme.textMuted)

            Text(VNDCurrency.format(amount))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
