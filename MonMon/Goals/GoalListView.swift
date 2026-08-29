import SwiftData
import SwiftUI

struct GoalListView: View {
    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @State private var editorMode: GoalEditorMode?

    let plannedByJar: [UUID: Decimal]
    let asOf: Date

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        GoalCommitmentWarnings(
                            jars: jars,
                            goals: goals,
                            plannedByJar: plannedByJar
                        )

                        if goals.isEmpty {
                            GoalEmptyState { editorMode = .add }
                        } else {
                            GoalCollection(
                                goals: goals,
                                jars: jars,
                                asOf: asOf,
                                onSelect: { editorMode = .edit($0) }
                            )
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add goal", systemImage: "plus") {
                        editorMode = .add
                    }
                    .accessibilityIdentifier("goal-add")
                }
            }
            .appSheet(item: $editorMode) { mode in
                GoalEditorView(mode: mode, plannedByJar: plannedByJar, asOf: asOf)
            }
            .tint(MonMonTheme.accent)
            .accessibilityIdentifier("goal-list")
        }
    }
}

private struct GoalCollection: View {
    let activeGoals: [FinancialGoal]
    let completedGoals: [FinancialGoal]
    let jarNames: [UUID: String]
    let asOf: Date
    let onSelect: (FinancialGoal) -> Void

    init(
        goals: [FinancialGoal],
        jars: [BudgetJar],
        asOf: Date,
        onSelect: @escaping (FinancialGoal) -> Void
    ) {
        activeGoals = goals.filter { $0.earmarkedAmount < $0.targetAmount }
        completedGoals = goals.filter { $0.earmarkedAmount >= $0.targetAmount }
        jarNames = Dictionary(uniqueKeysWithValues: jars.map { ($0.id, $0.name) })
        self.asOf = asOf
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !activeGoals.isEmpty {
                section("In progress", goals: activeGoals)
            }

            if !completedGoals.isEmpty {
                section("Completed", goals: completedGoals)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, goals: [FinancialGoal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            ForEach(goals) { goal in
                Button {
                    onSelect(goal)
                } label: {
                    GoalCard(
                        goal: goal,
                        jarName: goal.fundingJarID.flatMap { jarNames[$0] }
                            ?? String(localized: "No jar"),
                        asOf: asOf
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goal-\(goal.id.uuidString)")
                .accessibilityHint("Opens this goal for editing")
            }
        }
    }
}

private struct GoalCommitmentWarnings: View {
    struct Notice: Identifiable {
        let jarID: UUID
        let jarName: String
        let amount: Decimal

        var id: UUID { jarID }
    }

    let notices: [Notice]

    init(jars: [BudgetJar], goals: [FinancialGoal], plannedByJar: [UUID: Decimal]) {
        notices = jars.compactMap { jar in
            let snapshot = GoalCommitment.snapshot(
                jarID: jar.id,
                goals: goals,
                plannedCapacity: plannedByJar[jar.id, default: .zero]
            )
            guard snapshot.isOvercommitted else {
                return nil
            }
            return Notice(
                jarID: jar.id,
                jarName: jar.name,
                amount: snapshot.overcommittedAmount
            )
        }
    }

    var body: some View {
        ForEach(notices) { notice in
            Label {
                Text(
                    "\(notice.jarName) is overcommitted by \(VNDCurrency.format(notice.amount)) per month."
                )
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.danger)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("goal-overcommitted-\(notice.jarID.uuidString)")
        }
    }
}

private struct GoalEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("No goals yet")
                    .font(.title3.weight(.semibold))

                Text("Create a home, vehicle, trip, or custom target and fund it from a jar.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button("Create a goal", action: onAdd)
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("goal-empty-add")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}
