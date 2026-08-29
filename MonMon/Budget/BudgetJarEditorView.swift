import SwiftData
import SwiftUI

enum BudgetJarEditorMode: Identifiable {
    case add
    case edit(BudgetJar)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let jar):
            jar.id.uuidString
        }
    }

    var editedJar: BudgetJar? {
        switch self {
        case .add:
            nil
        case .edit(let jar):
            jar
        }
    }
}

struct BudgetJarEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \FinancialGoal.createdAt, order: .forward)
    private var goals: [FinancialGoal]

    private let mode: BudgetJarEditorMode

    @State private var draft: BudgetJarDraft
    @State private var validationError: BudgetJarFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false

    private let symbolColumns = [GridItem(.adaptive(minimum: 52), spacing: 10)]
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    init(mode: BudgetJarEditorMode) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: BudgetJarDraft(allocationText: "0"))
        case .edit(let jar):
            _draft = State(initialValue: BudgetJarDraft(jar: jar))
        }
    }

    var body: some View {
        #if os(macOS)
            editor
                .frame(minWidth: 460, minHeight: 640)
        #else
            editor
        #endif
    }

    private var editor: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        introduction
                        detailsCard
                        styleCard

                        if let saveErrorMessage {
                            validationMessage(saveErrorMessage)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    MonMonTheme.danger.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }

                        if let jar = mode.editedJar {
                            deletionSection(for: jar)
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(mode.editedJar == nil ? "Add jar" : "Edit jar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("budget-save-jar")
                }
            }
            .confirmationDialog(
                "Delete this jar?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteJar()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Categories mapped here will move to another available jar.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: CategoryPalette.symbolName(draft.symbolName))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(
                    CategoryPalette.color(named: draft.colorName),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.editedJar == nil ? "Create a money jar" : "Shape this money jar")
                    .font(.title3.weight(.semibold))

                Text("The percentage sets its monthly plan from recurring income.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                Label("Jar details", systemImage: "shippingbox.fill")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline.weight(.medium))

                    TextField("Necessities", text: $draft.name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .accessibilityIdentifier("budget-jar-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly allocation")
                        .font(.subheadline.weight(.medium))

                    HStack {
                        TextField("10", text: $draft.allocationText)
                            .textFieldStyle(.plain)
                            #if os(iOS)
                                .keyboardType(.decimalPad)
                            #endif

                        Text("%")
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
                    .padding(14)
                    .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("budget-jar-allocation")

                    if let allocationErrorMessage {
                        validationMessage(allocationErrorMessage)
                    }
                }
            }
        }
    }

    private var styleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                Label("Style", systemImage: "paintpalette.fill")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Symbol")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: symbolColumns, spacing: 10) {
                        ForEach(CategoryPalette.symbolNames, id: \.self) { symbolName in
                            symbolButton(symbolName)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Colour")
                        .font(.subheadline.weight(.medium))

                    LazyVGrid(columns: colorColumns, spacing: 10) {
                        ForEach(CategoryPalette.colorNames, id: \.self) { colorName in
                            colorButton(colorName)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func deletionSection(for jar: BudgetJar) -> some View {
        if jar.isProtected {
            Label(
                "Savings and Investment are system jars. You can rename or resize them, but not delete them.",
                systemImage: "lock.fill"
            )
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("budget-protected-jar-note")
        } else {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("Delete jar", systemImage: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MonMonTheme.danger)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .accessibilityIdentifier("budget-delete-jar")
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
                    in: RoundedRectangle(cornerRadius: 12)
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

    private func validationMessage(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
    }

    private var nameErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .emptyName:
            "Enter a jar name."
        case .duplicateName:
            "Another jar already has this name."
        default:
            nil
        }
    }

    private var allocationErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidPercent:
            "Enter a valid percentage."
        case .negativePercent:
            "The percentage cannot be negative."
        case .allocationExceeds100:
            "All jar percentages together cannot exceed 100%."
        default:
            nil
        }
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let editedJar = mode.editedJar {
                try draft.apply(to: editedJar, existing: jars)
            } else {
                modelContext.insert(
                    try draft.makeJar(id: UUID(), createdAt: .now, existing: jars)
                )
            }
        } catch let error as BudgetJarFormError {
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
            saveErrorMessage = "Couldn’t save this jar. Try again."
        }
    }

    private func deleteJar() {
        guard let editedJar = mode.editedJar else {
            return
        }

        saveErrorMessage = nil

        do {
            try BudgetJarStore.delete(
                editedJar,
                jars: jars,
                categories: categories,
                goals: goals,
                in: modelContext
            )
            dismiss()
        } catch BudgetJarStoreError.jarFundsGoals {
            modelContext.rollback()
            saveErrorMessage = "Move or delete this jar’s goals before deleting the jar."
        } catch BudgetJarStoreError.jarFundsTrips {
            modelContext.rollback()
            saveErrorMessage = "This jar is part of Trip history and cannot be deleted."
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this jar. Try again."
        }
    }
}
