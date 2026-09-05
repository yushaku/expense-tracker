import SwiftData
import SwiftUI
import WidgetKit

struct QuickExpensePresetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]
    @AppStorage(TransactionDefaults.categoryStorageKey)
    private var defaultExpenseCategoryValue = ""

    @State private var draft: QuickExpensePresetDraft
    @State private var confirmsDiscard = false
    @State private var saveFailed = false
    @FocusState private var focusedField: Field?

    private let original: QuickExpensePresetDraft
    private let store = QuickExpensePresetStore()

    private enum Field: Hashable {
        case name, amount
    }

    init(preset: QuickExpensePreset) {
        let draft = QuickExpensePresetDraft(preset: preset)
        original = draft
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline.weight(.medium))
                        QuickExpensePresetTile(
                            symbol: draft.symbol,
                            amount: VNDCurrency.parse(draft.amountText).flatMap {
                                $0 > 0 ? $0 : nil
                            },
                            category: resolvedCategory,
                            usesDefault: draft.categoryID == nil
                        )
                        Text("Preview only. No expense will be recorded.")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    QuickExpenseAccountSummary()
                    nameField
                    amountField
                    categoryField
                    if saveFailed {
                        Label(
                            "Couldn’t save presets. Try again.",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.danger)
                    }
                }
                .padding(20)
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .background(MonMonTheme.canvas)
            .navigationTitle("Edit quick expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!hasChanges || validationError != nil || resolvedCategory == nil)
                        .accessibilityIdentifier("save-quick-expense-preset")
                }
                #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField = nil }
                    }
                #endif
            }
            .confirmationDialog(
                "Discard changes?", isPresented: $confirmsDiscard, titleVisibility: .visible
            ) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasChanges)
            .onChange(of: draft) { saveFailed = false }
        }
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
        .environment(\.locale, AppLanguage.stored.locale)
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 640)
        #endif
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name or emoji").font(.subheadline.weight(.medium))
            TextField("Name or emoji", text: $draft.symbol)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .amount }
                .padding(12)
                .frame(minHeight: 48)
                .background(MonMonTheme.field, in: .rect(cornerRadius: 12))
                .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-symbol")
            if validationError == .invalidName {
                errorMessage("Enter a name or emoji with 1–16 characters.")
            } else {
                Text("Up to 16 characters. This appears on the widget.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount (VND)").font(.subheadline.weight(.medium))
            HStack {
                VNDTextField("0", text: $draft.amountText)
                    .focused($focusedField, equals: .amount)
                    .monospacedDigit()
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Amount (VND)")
                    .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-amount")
                Text("₫")
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 48)
            .background(MonMonTheme.field, in: .rect(cornerRadius: 12))
            if validationError == .invalidAmount {
                errorMessage("Enter a positive whole amount in VND.")
            }
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expense category").font(.subheadline.weight(.medium))
            Picker("Expense category", selection: $draft.categoryID) {
                if let id = draft.categoryID, resolvedCategory == nil {
                    Text("Category unavailable").tag(UUID?.some(id))
                }
                if let defaultCategory {
                    Text("Default: \(defaultCategory.name)").tag(UUID?.none)
                } else {
                    Text("Default category unavailable").tag(UUID?.none)
                }
                ForEach(expenseCategories) { category in
                    Text(verbatim: category.name).tag(UUID?.some(category.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 12)
            .background(MonMonTheme.field, in: .rect(cornerRadius: 12))
            .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-category")
            if resolvedCategory == nil {
                errorMessage(
                    "Choose an expense category. Add one in Categories if the list is empty.")
            } else if draft.categoryID == nil {
                Text("Follows your default expense category when it changes.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private func errorMessage(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
    }

    private var expenseCategories: [TransactionCategory] {
        categories.filter { $0.kind == .expense }
    }

    private var defaultCategory: TransactionCategory? {
        let id = TransactionDefaults.resolveCategoryID(
            defaultExpenseCategoryValue, categories: categories)
        return expenseCategories.first { $0.id == id }
    }

    private var resolvedCategory: TransactionCategory? {
        guard let id = draft.categoryID else { return defaultCategory }
        return expenseCategories.first { $0.id == id }
    }

    private var validationError: QuickExpensePresetError? {
        do {
            _ = try draft.makePreset()
            return nil
        } catch let error as QuickExpensePresetError {
            return error
        } catch {
            return .invalidAmount
        }
    }

    private var hasChanges: Bool { draft != original }

    private func cancel() {
        if hasChanges {
            confirmsDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard resolvedCategory != nil else { return }
        do {
            try store.savePreset(draft.makePreset())
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
