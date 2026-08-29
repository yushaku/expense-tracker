import SwiftData
import SwiftUI

struct GoalCard: View {
    let goal: FinancialGoal
    let jarName: String
    let asOf: Date
    let showsDisclosure: Bool

    init(
        goal: FinancialGoal,
        jarName: String,
        asOf: Date,
        showsDisclosure: Bool = true
    ) {
        self.goal = goal
        self.jarName = jarName
        self.asOf = asOf
        self.showsDisclosure = showsDisclosure
    }

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

                Text(jarName)
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
            } else if showsDisclosure {
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

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    let goalID: UUID
    let plannedByJar: [UUID: Decimal]
    let asOf: Date

    @State private var editorMode: GoalEditorMode?

    private var goal: FinancialGoal? {
        goals.first { $0.id == goalID }
    }

    var body: some View {
        Group {
            if let goal {
                ZStack {
                    MonMonTheme.canvas
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                            GoalCard(
                                goal: goal,
                                jarName: jarName(for: goal),
                                asOf: asOf,
                                showsDisclosure: false
                            )

                            detailsCard(goal)
                        }
                        .frame(maxWidth: MonMonTheme.maxContentWidth)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Goal unavailable",
                    systemImage: "flag.slash",
                    description: Text("This goal is no longer in the current store.")
                )
            }
        }
        .navigationTitle(goal?.name ?? String(localized: "Goal"))
        .toolbar {
            if let goal {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit goal", systemImage: "pencil") {
                        editorMode = .edit(goal)
                    }
                    .accessibilityIdentifier("goal-detail-edit")
                }
            }
        }
        .appSheet(item: $editorMode) { mode in
            GoalEditorView(mode: mode, plannedByJar: plannedByJar, asOf: asOf)
        }
        .onChange(of: goal?.id) { _, currentGoalID in
            if currentGoalID == nil {
                dismiss()
            }
        }
        .tint(MonMonTheme.accent)
        .accessibilityIdentifier("goal-detail")
    }

    private func detailsCard(_ goal: FinancialGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Details")
                .font(.headline)

            detailRow("Type") {
                Text(goal.kind.title)
            }

            Divider()
                .overlay(MonMonTheme.border)

            detailRow("Funding jar") {
                Text(jarName(for: goal))
            }

            Divider()
                .overlay(MonMonTheme.border)

            detailRow("Target date") {
                Text(goal.targetDate, format: .dateTime.day().month().year())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func detailRow<Value: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 12)

            value()
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func jarName(for goal: FinancialGoal) -> String {
        guard let jarID = goal.fundingJarID else {
            return String(localized: "No jar")
        }

        return jars.first { $0.id == jarID }?.name ?? String(localized: "No jar")
    }
}
