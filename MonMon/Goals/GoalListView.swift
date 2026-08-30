import SwiftData
import SwiftUI

private struct GoalTripDestination: Hashable {
    let workspaceID: UUID
}

struct GoalListSnapshot {
    let activeGoals: [FinancialGoal]
    let completedGoals: [FinancialGoal]
    let archivedGoals: [FinancialGoal]
    let activeTrips: [TripWorkspace]
    let completedTrips: [TripWorkspace]

    static func snapshot(
        goals: [FinancialGoal],
        workspaces: [TripWorkspace]
    ) -> GoalListSnapshot {
        let startedGoalIDs = Set(workspaces.compactMap(\.sourceGoalID))
        let visibleGoals = goals.filter {
            $0.archivedAt == nil && !startedGoalIDs.contains($0.id)
        }
        let trips = TripWorkspaceCollection.snapshot(goals: goals, workspaces: workspaces)

        return GoalListSnapshot(
            activeGoals:
                visibleGoals
                .filter { $0.earmarkedAmount < $0.targetAmount }
                .sorted { $0.createdAt < $1.createdAt },
            completedGoals:
                visibleGoals
                .filter { $0.earmarkedAmount >= $0.targetAmount }
                .sorted { $0.createdAt < $1.createdAt },
            archivedGoals:
                goals
                .filter { $0.archivedAt != nil }
                .sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) },
            activeTrips: trips.activeWorkspaces,
            completedTrips: trips.completedWorkspaces
        )
    }
}

private enum GoalListFilter: String, CaseIterable, Identifiable {
    case active
    case completed
    case trips
    case archived

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .completed: "Completed"
        case .trips: "Trips"
        case .archived: "Archived"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "target"
        case .completed: "checkmark.circle.fill"
        case .trips: "airplane"
        case .archived: "archivebox.fill"
        }
    }
}

struct GoalListView: View {
    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @State private var editorMode: GoalEditorMode?
    @State private var selectedGoalID: UUID?
    @State private var selectedFilter: GoalListFilter = .active

    let plannedByJar: [UUID: Decimal]
    let asOf: Date

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        GoalFilterMenu(selection: $selectedFilter)
                        filteredContent
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Goals")
            .navigationDestination(for: GoalTripDestination.self) { destination in
                TripDestinationView(
                    workspaceID: destination.workspaceID,
                    workspaces: tripWorkspaces
                )
            }
            .navigationDestination(item: $selectedGoalID) { goalID in
                GoalDetailView(goalID: goalID, plannedByJar: plannedByJar, asOf: asOf)
            }
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

    private var listSnapshot: GoalListSnapshot {
        GoalListSnapshot.snapshot(goals: goals, workspaces: tripWorkspaces)
    }

    @ViewBuilder
    private var filteredContent: some View {
        switch selectedFilter {
        case .active:
            GoalCommitmentWarnings(
                jars: jars,
                goals: goals,
                plannedByJar: plannedByJar
            )

            if listSnapshot.activeGoals.isEmpty {
                GoalEmptyState { editorMode = .add }
            } else {
                goalCollection(title: "Accumulating", goals: listSnapshot.activeGoals)
            }
        case .completed:
            if listSnapshot.completedGoals.isEmpty {
                filteredEmptyState(
                    "No completed goals",
                    systemImage: "checkmark.circle",
                    description: "Goals that reach their target will appear here."
                )
            } else {
                goalCollection(title: "Completed", goals: listSnapshot.completedGoals)
            }
        case .trips:
            if listSnapshot.activeTrips.isEmpty && listSnapshot.completedTrips.isEmpty {
                filteredEmptyState(
                    "No trips yet",
                    systemImage: "airplane",
                    description: "Start a spending workspace from a funded goal."
                )
            } else {
                TripWorkspaceSection(
                    title: "Active trips",
                    workspaces: listSnapshot.activeTrips,
                    transactions: transactions,
                    categories: categories
                )
                TripWorkspaceSection(
                    title: "History",
                    workspaces: listSnapshot.completedTrips,
                    transactions: transactions,
                    categories: categories
                )
            }
        case .archived:
            if listSnapshot.archivedGoals.isEmpty {
                filteredEmptyState(
                    "No archived goals",
                    systemImage: "archivebox",
                    description: "Archived completed goals will appear here."
                )
            } else {
                goalCollection(title: "Archived", goals: listSnapshot.archivedGoals)
            }
        }
    }

    private func goalCollection(
        title: LocalizedStringKey,
        goals: [FinancialGoal]
    ) -> some View {
        GoalCollection(
            title: title,
            goals: goals,
            jars: jars,
            asOf: asOf,
            onSelect: { selectedGoalID = $0.id }
        )
    }

    private func filteredEmptyState(
        _ title: LocalizedStringKey,
        systemImage: String,
        description: LocalizedStringKey
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

private struct GoalFilterMenu: View {
    @Binding var selection: GoalListFilter

    var body: some View {
        HStack(spacing: 12) {
            Text("Show")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            Menu {
                ForEach(GoalListFilter.allCases) { filter in
                    Button {
                        selection = filter
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                }
            } label: {
                Label(selection.title, systemImage: selection.systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel("Goal filter")
            .accessibilityValue(Text(selection.title))
            .accessibilityIdentifier("goal-filter")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}

private struct TripWorkspaceSection: View {
    let title: LocalizedStringKey
    let workspaces: [TripWorkspace]
    let snapshots: [UUID: TripSummarySnapshot]

    init(
        title: LocalizedStringKey,
        workspaces: [TripWorkspace],
        transactions: [MoneyTransaction],
        categories: [TransactionCategory]
    ) {
        self.title = title
        self.workspaces = workspaces
        snapshots = Dictionary(
            uniqueKeysWithValues: workspaces.map { workspace in
                (
                    workspace.id,
                    TripSummary.snapshot(
                        workspace: workspace,
                        transactions: transactions,
                        categories: categories
                    )
                )
            }
        )
    }

    var body: some View {
        if !workspaces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))

                ForEach(workspaces) { workspace in
                    NavigationLink(value: GoalTripDestination(workspaceID: workspace.id)) {
                        TripWorkspaceCard(
                            workspace: workspace,
                            snapshot: snapshots[workspace.id]
                                ?? TripSummary.snapshot(
                                    workspace: workspace,
                                    transactions: [],
                                    categories: []
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this trip workspace")
                    .accessibilityIdentifier("trip-\(workspace.id.uuidString)")
                }
            }
        }
    }
}

private struct TripDestinationView: View {
    let workspace: TripWorkspace?

    init(workspaceID: UUID, workspaces: [TripWorkspace]) {
        workspace = workspaces.first { $0.id == workspaceID }
    }

    var body: some View {
        if let workspace {
            TripDetailView(workspace: workspace)
        } else {
            ContentUnavailableView(
                "Trip unavailable",
                systemImage: "airplane",
                description: Text("This trip is no longer in the current store.")
            )
        }
    }
}

private struct GoalCollection: View {
    let title: LocalizedStringKey
    let goals: [FinancialGoal]
    let jarNames: [UUID: String]
    let asOf: Date
    let onSelect: (FinancialGoal) -> Void

    init(
        title: LocalizedStringKey,
        goals: [FinancialGoal],
        jars: [BudgetJar],
        asOf: Date,
        onSelect: @escaping (FinancialGoal) -> Void
    ) {
        self.title = title
        self.goals = goals
        jarNames = Dictionary(uniqueKeysWithValues: jars.map { ($0.id, $0.name) })
        self.asOf = asOf
        self.onSelect = onSelect
    }

    var body: some View {
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
                .accessibilityHint("Opens this goal's details")
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
