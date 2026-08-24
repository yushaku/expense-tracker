import SwiftData
import SwiftUI

enum RecurringEditorMode: Identifiable {
    case add
    case edit(RecurringRule)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let rule):
            rule.id.uuidString
        }
    }

    var editedRule: RecurringRule? {
        switch self {
        case .add:
            nil
        case .edit(let rule):
            rule
        }
    }
}

struct RecurringEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @AppStorage(TransactionDefaults.accountStorageKey)
    private var defaultTransactionAccountValue = ""
    @AppStorage(TransactionDefaults.categoryStorageKey)
    private var defaultTransactionCategoryValue = ""

    private let mode: RecurringEditorMode
    /// Passed in rather than read from the clock inside, so what the editor
    /// backfills is decided by one value the whole screen agrees on.
    private let asOf: Date

    @State private var draft: RecurringRuleDraft
    @State private var validationError: RecurringFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false
    @State private var didApplyDefaults = false

    init(mode: RecurringEditorMode, defaultDate: Date = .now, asOf: Date = .now) {
        self.mode = mode
        self.asOf = asOf

        switch mode {
        case .add:
            _draft = State(initialValue: RecurringRuleDraft(anchorDate: defaultDate))
        case .edit(let rule):
            _draft = State(initialValue: RecurringRuleDraft(rule: rule))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 620)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            RecurringEditorForm(
                draft: $draft,
                accounts: accounts,
                categories: categories,
                isEditing: mode.editedRule != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedRule == nil ? "Add rule" : "Edit rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-recurring")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-recurring")
                }
            }
            .confirmationDialog(
                "Delete this rule?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-recurring")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("What it already recorded stays, and no balance moves.")
            }
            .onChange(of: draft.kind) { _, _ in
                clearCategoryIfDirectionChanged()
            }
            .onAppear {
                applyDefaultsIfNeeded()
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// A new rule starts on the same account and category a new transaction
    /// does, because it is the same money seen ahead of time.
    private func applyDefaultsIfNeeded() {
        guard !didApplyDefaults, mode.editedRule == nil else {
            return
        }

        didApplyDefaults = true
        var transactionDraft = TransactionDraft(occurredAt: draft.anchorDate)
        TransactionDefaults.apply(
            accountValue: defaultTransactionAccountValue,
            categoryValue: defaultTransactionCategoryValue,
            accounts: accounts,
            categories: categories,
            to: &transactionDraft
        )

        draft.kind = transactionDraft.kind
        draft.accountID = transactionDraft.accountID
        draft.categoryID = transactionDraft.categoryID
    }

    /// Switching between income and expense strands a category from the other
    /// direction, which the picker no longer offers.
    private func clearCategoryIfDirectionChanged() {
        guard let categoryID = draft.categoryID else {
            return
        }

        let stillOffered = categories.contains {
            $0.id == categoryID && $0.kind == draft.kind
        }

        if !stillOffered {
            draft.categoryID = nil
        }
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let editedRule = mode.editedRule {
                try draft.apply(to: editedRule, asOf: asOf)
            } else {
                let rule = try draft.makeRule(id: UUID(), createdAt: asOf, asOf: asOf)
                modelContext.insert(rule)
            }
        } catch let error as RecurringFormError {
            validationError = error
            return
        } catch {
            saveErrorMessage = "Something went wrong. Try again."
            return
        }

        do {
            try modelContext.save()
            // Saved first, so a rule that fails to write records nothing. What
            // it owes is recorded now rather than at the next launch, because a
            // rule the owner just wrote should show its entries straight away.
            try RecurringGenerator.generate(in: modelContext, asOf: asOf)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save this rule. Try again."
        }
    }

    /// The transactions this rule already wrote are money that already moved, so
    /// they stay and no balance changes.
    private func delete() {
        guard let editedRule = mode.editedRule else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedRule)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this rule. Try again."
        }
    }
}
