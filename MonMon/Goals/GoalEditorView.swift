import SwiftData
import SwiftUI

enum GoalEditorMode: Identifiable {
    case add
    case edit(FinancialGoal)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let goal):
            goal.id.uuidString
        }
    }

    var editedGoal: FinancialGoal? {
        switch self {
        case .add:
            nil
        case .edit(let goal):
            goal
        }
    }
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    private let mode: GoalEditorMode
    private let plannedByJar: [UUID: Decimal]
    private let asOf: Date

    @State private var draft: FinancialGoalDraft
    @State private var validationError: FinancialGoalFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false

    init(mode: GoalEditorMode, plannedByJar: [UUID: Decimal], asOf: Date) {
        self.mode = mode
        self.plannedByJar = plannedByJar
        self.asOf = asOf

        switch mode {
        case .add:
            let targetDate = Calendar.current.date(byAdding: .year, value: 1, to: asOf) ?? asOf
            _draft = State(initialValue: FinancialGoalDraft(targetDate: targetDate))
        case .edit(let goal):
            _draft = State(initialValue: FinancialGoalDraft(goal: goal))
        }
    }

    var body: some View {
        #if os(macOS)
            editor
                .frame(minWidth: 480, minHeight: 680)
        #else
            editor
        #endif
    }

    private var editor: some View {
        NavigationStack {
            GoalEditorForm(
                draft: $draft,
                jars: jars,
                plannedCapacity: draft.fundingJarID.flatMap { plannedByJar[$0] } ?? .zero,
                isEditing: mode.editedGoal != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                minimumTargetDate: Calendar.current.startOfDay(for: asOf),
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedGoal == nil ? "Add goal" : "Edit goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("goal-save")
                }
            }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the earmark only. It does not move or delete financial records.")
            }
            .task {
                if draft.fundingJarID == nil {
                    draft.fundingJarID = jars.first { $0.role == .savings }?.id ?? jars.first?.id
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let goal = mode.editedGoal {
                try draft.apply(
                    to: goal,
                    jars: jars,
                    goals: goals,
                    plannedByJar: plannedByJar,
                    asOf: asOf
                )
            } else {
                modelContext.insert(
                    try draft.makeGoal(
                        id: UUID(),
                        createdAt: .now,
                        jars: jars,
                        goals: goals,
                        plannedByJar: plannedByJar,
                        asOf: asOf
                    )
                )
            }
        } catch let error as FinancialGoalFormError {
            validationError = error
            return
        } catch {
            saveErrorMessage = "Something went wrong. Try again."
            return
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save this goal. Try again."
        }
    }

    private func delete() {
        guard let goal = mode.editedGoal else {
            return
        }

        modelContext.delete(goal)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this goal. Try again."
        }
    }
}

private struct GoalEditorForm: View {
    @Binding var draft: FinancialGoalDraft

    let jars: [BudgetJar]
    let plannedCapacity: Decimal
    let isEditing: Bool
    let validationError: FinancialGoalFormError?
    let saveErrorMessage: LocalizedStringKey?
    let minimumTargetDate: Date
    let onDelete: () -> Void

    private let symbolColumns = [GridItem(.adaptive(minimum: 52), spacing: 10)]
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    detailsCard
                    moneyCard
                    scheduleCard
                    styleCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteButton
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: CategoryPalette.symbolName(draft.symbolName))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(CategoryPalette.color(named: draft.colorName))
                .frame(width: 46, height: 46)
                .background(
                    CategoryPalette.color(named: draft.colorName).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Shape this goal" : "Create a financial target")
                    .font(.title3.weight(.semibold))

                Text("Goal money stays inside its jar and is never counted as a second asset.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Goal", systemImage: "flag.checkered")

                field("Name", error: nameError) {
                    TextField("Goal name", text: $draft.name)
                        .accessibilityIdentifier("goal-name")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Funding jar")
                        .font(.subheadline.weight(.medium))

                    Picker("Funding jar", selection: $draft.fundingJarID) {
                        Text("Choose a jar").tag(UUID?.none)
                        ForEach(jars) { jar in
                            Text(jar.name).tag(Optional(jar.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("goal-jar")

                    if let jarError {
                        validationMessage(jarError)
                    }
                }
            }
        }
    }

    private var moneyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Money", systemImage: "banknote.fill")

                field("Target amount", error: targetError) {
                    VNDTextField(text: $draft.targetAmountText)
                        .accessibilityIdentifier("goal-target")
                }

                field("Already earmarked", error: earmarkedError) {
                    VNDTextField(text: $draft.earmarkedAmountText)
                        .accessibilityIdentifier("goal-earmarked")
                }
            }
        }
    }

    private var scheduleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Monthly plan", systemImage: "calendar")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target date")
                        .font(.subheadline.weight(.medium))

                    DatePicker(
                        "Target date",
                        selection: $draft.targetDate,
                        in: minimumTargetDate...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .accessibilityLabel("Target date")
                    .accessibilityIdentifier("goal-target-date")

                    if let dateError {
                        validationMessage(dateError)
                    }
                }

                field("Planned contribution", error: contributionError) {
                    VNDTextField(text: $draft.monthlyContributionText)
                        .accessibilityIdentifier("goal-monthly")
                }

                Text("Jar plan this month: \(VNDCurrency.format(plannedCapacity))")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                if validationError == .monthlyCommitmentExceedsJar {
                    validationMessage(
                        "This jar does not have enough uncommitted monthly plan for the goal."
                    )
                }
            }
        }
    }

    private var styleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Style", systemImage: "paintpalette.fill")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Symbol")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: symbolColumns, spacing: 10) {
                        ForEach(CategoryPalette.symbolNames, id: \.self) { symbolName in
                            symbolButton(symbolName)
                        }
                    }
                    .accessibilityIdentifier("goal-symbol")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Colour")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: colorColumns, spacing: 10) {
                        ForEach(CategoryPalette.colorNames, id: \.self) { colorName in
                            colorButton(colorName)
                        }
                    }
                    .accessibilityIdentifier("goal-color")
                }
            }
        }
    }

    private func symbolButton(_ symbolName: String) -> some View {
        let isSelected = draft.symbolName == symbolName

        return Button {
            draft.symbolName = symbolName
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? MonMonTheme.onAccent : MonMonTheme.textSecondary)
                .frame(width: 52, height: 44)
                .background(
                    isSelected
                        ? CategoryPalette.color(named: draft.colorName) : MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbolName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func colorButton(_ colorName: String) -> some View {
        let isSelected = draft.colorName == colorName

        return Button {
            draft.colorName = colorName
        } label: {
            Circle()
                .fill(CategoryPalette.color(named: colorName))
                .frame(width: 34, height: 34)
                .overlay {
                    // The tick, not the ring alone, says which colour is chosen.
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MonMonTheme.onAccent)
                    }
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func field<Content: View>(
        _ label: LocalizedStringKey,
        error: LocalizedStringKey?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))

            content()
                .textFieldStyle(.plain)
                .padding(14)
                .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))

            if let error {
                validationMessage(error)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private func validationMessage(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
    }

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
        validationMessage(message)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete goal", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.danger)
        .background(MonMonTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("goal-delete")
    }

    private var nameError: LocalizedStringKey? {
        validationError == .emptyName ? "Enter a goal name." : nil
    }

    private var targetError: LocalizedStringKey? {
        switch validationError {
        case .invalidTargetAmount:
            "Enter a valid target amount."
        case .nonPositiveTargetAmount:
            "The target must be greater than zero."
        default:
            nil
        }
    }

    private var earmarkedError: LocalizedStringKey? {
        switch validationError {
        case .invalidEarmarkedAmount:
            "Enter a valid earmarked amount."
        case .negativeEarmarkedAmount:
            "The earmarked amount cannot be negative."
        case .earmarkedExceedsTarget:
            "The earmarked amount cannot exceed the target."
        default:
            nil
        }
    }

    private var contributionError: LocalizedStringKey? {
        switch validationError {
        case .invalidMonthlyContribution:
            "Enter a valid monthly contribution."
        case .negativeMonthlyContribution:
            "The monthly contribution cannot be negative."
        default:
            nil
        }
    }

    private var dateError: LocalizedStringKey? {
        validationError == .targetDateInPast ? "Choose today or a future date." : nil
    }

    private var jarError: LocalizedStringKey? {
        validationError == .missingFundingJar ? "Choose a funding jar." : nil
    }
}
