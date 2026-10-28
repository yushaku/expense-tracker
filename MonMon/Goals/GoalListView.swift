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
    let archivedTrips: [TripWorkspace]

    var isEmpty: Bool {
        activeGoals.isEmpty && completedGoals.isEmpty && activeTrips.isEmpty
            && completedTrips.isEmpty
    }

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
                .filter { $0.archivedAt != nil && !startedGoalIDs.contains($0.id) }
                .sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) },
            activeTrips: trips.activeWorkspaces,
            completedTrips: trips.completedWorkspaces,
            archivedTrips: trips.archivedWorkspaces
        )
    }
}

private enum GoalListFilter: String, CaseIterable, Identifiable {
    case active
    case archived

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .archived: "Archived"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "target"
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

    /// Only rows linked to some trip; the trip cards read nothing else.
    @Query(
        filter: #Predicate<MoneyTransaction> { $0.tripWorkspaceID != nil },
        sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var tripTransactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @State private var editorMode: GoalEditorMode?
    @State private var selectedGoalID: UUID?
    @State private var selectedFilter: GoalListFilter = .active

    let capacityByJar: [UUID: Decimal]
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
                GoalDetailView(goalID: goalID, asOf: asOf)
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
                GoalEditorView(mode: mode, capacityByJar: capacityByJar, asOf: asOf)
            }
            .tint(MonMonTheme.accent)
            .accessibilityIdentifier("goal-list")
        }
    }

    @ViewBuilder
    private var filteredContent: some View {
        // Worked out once per update, for whichever filter is showing, rather
        // than each time a section asks.
        let snapshot = GoalListSnapshot.snapshot(goals: goals, workspaces: tripWorkspaces)
        // One pass groups the trip rows by trip; each card then reads its own.
        let rowsByTrip = Dictionary(grouping: tripTransactions) { $0.tripWorkspaceID }

        switch selectedFilter {
        case .active:
            GoalCommitmentWarnings(
                jars: jars,
                goals: goals,
                capacityByJar: capacityByJar
            )

            if snapshot.isEmpty {
                GoalEmptyState { editorMode = .add }
            } else {
                goalCollection(title: "Accumulating", goals: snapshot.activeGoals)
                goalCollection(title: "Ready to spend", goals: snapshot.completedGoals)
                TripWorkspaceSection(
                    title: "Spending",
                    workspaces: snapshot.activeTrips,
                    rowsByTrip: rowsByTrip,
                    categories: categories
                )
                TripWorkspaceSection(
                    title: "Completed",
                    workspaces: snapshot.completedTrips,
                    rowsByTrip: rowsByTrip,
                    categories: categories
                )
            }
        case .archived:
            if snapshot.archivedGoals.isEmpty && snapshot.archivedTrips.isEmpty {
                filteredEmptyState(
                    "No archived items",
                    systemImage: "archivebox",
                    description: "Archived completed goals and trips will appear here."
                )
            } else {
                goalCollection(title: "Archived goals", goals: snapshot.archivedGoals)
                TripWorkspaceSection(
                    title: "Archived trips",
                    workspaces: snapshot.archivedTrips,
                    rowsByTrip: rowsByTrip,
                    categories: categories
                )
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
    /// Trip-linked rows grouped by trip, built once by the list.
    let rowsByTrip: [UUID?: [MoneyTransaction]]
    let categories: [TransactionCategory]

    var body: some View {
        if !workspaces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))

                ForEach(workspaces) { workspace in
                    NavigationLink(value: GoalTripDestination(workspaceID: workspace.id)) {
                        TripWorkspaceCard(
                            workspace: workspace,
                            snapshot: TripSummary.snapshot(
                                workspace: workspace,
                                transactions: rowsByTrip[workspace.id] ?? [],
                                categories: categories
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
            GoalDetailView(workspace: workspace)
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
        jarNames = Dictionary(firstWins: jars.map { ($0.id, $0.name) })
        self.asOf = asOf
        self.onSelect = onSelect
    }

    var body: some View {
        if !goals.isEmpty {
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
}

private struct GoalCommitmentWarnings: View {
    struct Notice: Identifiable {
        let jarID: UUID
        let jarName: String
        let amount: Decimal

        var id: UUID { jarID }
    }

    let notices: [Notice]

    init(jars: [BudgetJar], goals: [FinancialGoal], capacityByJar: [UUID: Decimal]) {
        notices = jars.compactMap { jar in
            let snapshot = GoalCommitment.snapshot(
                jarID: jar.id,
                goals: goals,
                plannedCapacity: capacityByJar[jar.id, default: .zero]
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
