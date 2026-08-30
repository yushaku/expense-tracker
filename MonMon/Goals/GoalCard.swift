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
            GoalActionStatusBanner(
                status: GoalActionStatus.resolve(
                    progress: snapshot,
                    isArchived: goal.archivedAt != nil
                ),
                tint: tint
            )
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

private struct GoalActionStatusBanner: View {
    let status: GoalActionStatus
    let tint: Color

    private var statusTint: Color {
        switch status {
        case .needsMonthly:
            MonMonTheme.danger
        case .onTrack, .readyToUse:
            tint
        case .archived:
            MonMonTheme.textSecondary
        }
    }

    var body: some View {
        Label {
            switch status {
            case .onTrack:
                Text("On track")
            case .needsMonthly(let amount):
                Text("Needs \(VNDCurrency.format(amount)) more this month")
            case .readyToUse:
                Text("Ready to use")
            case .archived:
                Text("Archived")
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(statusTint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("goal-action-status")
    }

    private var systemImage: String {
        switch status {
        case .onTrack:
            "checkmark.circle.fill"
        case .needsMonthly:
            "exclamationmark.triangle.fill"
        case .readyToUse:
            "arrow.up.forward.circle.fill"
        case .archived:
            "archivebox.fill"
        }
    }
}

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    let goalID: UUID
    let capacityByJar: [UUID: Decimal]
    let asOf: Date

    @State private var editorMode: GoalEditorMode?
    @State private var isShowingUseOptions = false
    @State private var isShowingContribution = false
    @State private var selectedWorkspaceID: UUID?
    @State private var startErrorMessage: LocalizedStringKey?

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
                            GoalContributionCard(
                                goal: goal,
                                onMarkContribution: { isShowingContribution = true }
                            )
                            useAmountCard(goal)
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
                if goal.archivedAt == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit goal", systemImage: "pencil") {
                            editorMode = .edit(goal)
                        }
                        .accessibilityIdentifier("goal-detail-edit")
                    }
                }

                if goal.archivedAt != nil || goal.earmarkedAmount >= goal.targetAmount {
                    ToolbarItem(placement: .secondaryAction) {
                        GoalArchiveMenu(goal: goal)
                    }
                }
            }
        }
        .appSheet(item: $editorMode) { mode in
            GoalEditorView(mode: mode, capacityByJar: capacityByJar, asOf: asOf)
        }
        .appSheet(isPresented: $isShowingContribution) {
            if let goal {
                GoalContributionEditor(goal: goal)
            }
        }
        .navigationDestination(item: $selectedWorkspaceID) { workspaceID in
            if let workspace = tripWorkspaces.first(where: { $0.id == workspaceID }) {
                TripDetailView(workspace: workspace)
            } else {
                ContentUnavailableView(
                    "Trip unavailable",
                    systemImage: "airplane",
                    description: Text("This trip is no longer in the current store.")
                )
            }
        }
        .confirmationDialog(
            "Use this amount",
            isPresented: $isShowingUseOptions,
            titleVisibility: .visible
        ) {
            Button("Start a trip", systemImage: "airplane.departure") {
                startTrip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The accumulated amount will become this trip's budget.")
        }
        .alert(
            "Couldn’t start this trip",
            isPresented: startErrorBinding,
            presenting: startErrorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
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

    @ViewBuilder
    private func useAmountCard(_ goal: FinancialGoal) -> some View {
        if let workspace = workspace(for: goal) {
            Button("Open trip", systemImage: "airplane") {
                selectedWorkspaceID = workspace.id
            }
            .buttonStyle(.prominentAction)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier("goal-open-trip")
        } else if canUse(goal) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Use this amount")
                    .font(.headline)

                Text("Turn the money accumulated so far into a separate spending workspace.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Button("Use this amount", systemImage: "arrow.up.forward.app") {
                    isShowingUseOptions = true
                }
                .buttonStyle(.prominentAction)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("goal-use-amount")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
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

    private func workspace(for goal: FinancialGoal) -> TripWorkspace? {
        tripWorkspaces.first { $0.sourceGoalID == goal.id }
    }

    private func canUse(_ goal: FinancialGoal) -> Bool {
        TripWorkspaceCollection.snapshot(goals: [goal], workspaces: tripWorkspaces)
            .usableGoalIDs.contains(goal.id)
    }

    private var startErrorBinding: Binding<Bool> {
        Binding(
            get: { startErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    startErrorMessage = nil
                }
            }
        )
    }

    private func startTrip() {
        guard let goal else {
            return
        }

        startErrorMessage = nil
        do {
            let workspace = try TripWorkspaceLifecycle.start(
                goal: goal,
                existingWorkspaces: tripWorkspaces,
                id: UUID(),
                startedAt: .now,
                in: modelContext
            )
            selectedWorkspaceID = workspace.id
        } catch TripWorkspaceLifecycleError.workspaceAlreadyExists {
            startErrorMessage = "This goal already has a trip workspace."
        } catch TripWorkspaceLifecycleError.goalHasNoFunds {
            startErrorMessage = "Add money to this goal before using it."
        } catch TripWorkspaceLifecycleError.missingFundingJar {
            startErrorMessage = "Choose a funding jar before using this goal."
        } catch {
            startErrorMessage = "Couldn’t save your changes. Please try again."
        }
    }
}

private struct GoalArchiveMenu: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: FinancialGoal

    @State private var isConfirmingArchive = false
    @State private var updateFailed = false

    var body: some View {
        Menu("More", systemImage: "ellipsis.circle") {
            if goal.archivedAt == nil {
                Button("Archive goal", systemImage: "archivebox") {
                    isConfirmingArchive = true
                }
            } else {
                Button("Restore goal", systemImage: "arrow.uturn.backward.circle") {
                    restore()
                }
            }
        }
        .accessibilityIdentifier("goal-more-actions")
        .confirmationDialog(
            "Archive this goal?",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) { archive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The goal moves out of active views. Its earmark and contribution history stay intact."
            )
        }
        .alert("Couldn’t update this goal", isPresented: $updateFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your changes were not saved. Please try again.")
        }
    }

    private func archive() {
        do {
            try GoalArchive.archive(goal, at: .now)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            updateFailed = true
        }
    }

    private func restore() {
        GoalArchive.restore(goal)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            updateFailed = true
        }
    }
}

private struct GoalContributionCard: View {
    let goal: FinancialGoal
    let onMarkContribution: () -> Void

    private var entries: [GoalContribution] {
        GoalContributionStore.entries(for: goal).reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Contributions")
                    .font(.headline)

                Spacer(minLength: 8)

                if goal.earmarkedAmount < goal.targetAmount {
                    Button("Mark contribution", systemImage: "plus.circle.fill") {
                        onMarkContribution()
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("goal-mark-contribution")
                }
            }

            if entries.isEmpty {
                Text("New contributions will appear here. The starting earmark is kept separate.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                ForEach(entries) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(entry.occurredAt, format: .dateTime.day().month().year())
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)

                        Spacer(minLength: 12)

                        Text("+\(VNDCurrency.format(entry.amount))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)

                    if entry.id != entries.last?.id {
                        Divider()
                            .overlay(MonMonTheme.border)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goal-contributions")
    }
}

private struct GoalContributionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: FinancialGoal

    @State private var amountText = ""
    @State private var occurredAt = Date.now
    @State private var errorMessage: LocalizedStringKey?

    private var remaining: Decimal {
        max(0, goal.targetAmount - goal.earmarkedAmount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contribution") {
                    VNDTextField(text: $amountText)
                        .accessibilityLabel("Contribution amount")
                        .accessibilityIdentifier("goal-contribution-amount")

                    DatePicker(
                        "Date",
                        selection: $occurredAt,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("goal-contribution-date")

                    Text("Remaining: \(VNDCurrency.format(remaining))")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(MonMonTheme.danger)
                    }
                }
            }
            .navigationTitle("Mark contribution")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("goal-contribution-save")
                }
            }
            .tint(MonMonTheme.accent)
        }
    }

    private func save() {
        errorMessage = nil
        guard let amount = VNDCurrency.parse(amountText) else {
            errorMessage = "Enter a valid contribution amount."
            return
        }

        do {
            try GoalContributionStore.record(
                amount: amount,
                on: goal,
                id: UUID(),
                occurredAt: occurredAt
            )
            try modelContext.save()
            dismiss()
        } catch GoalContributionError.nonPositiveAmount {
            errorMessage = "The contribution must be greater than zero."
        } catch GoalContributionError.exceedsRemaining {
            errorMessage = "The contribution cannot exceed the remaining goal amount."
        } catch {
            modelContext.rollback()
            errorMessage = "Couldn’t save this contribution. Try again."
        }
    }
}
