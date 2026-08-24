import SwiftData
import SwiftUI

enum TransactionEditorMode: Identifiable {
    case add
    case edit(MoneyTransaction)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let transaction):
            transaction.id.uuidString
        }
    }

    var editedTransaction: MoneyTransaction? {
        switch self {
        case .add:
            nil
        case .edit(let transaction):
            transaction
        }
    }
}

struct TransactionEditorView: View {
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

    private let mode: TransactionEditorMode

    @State private var draft: TransactionDraft
    @State private var validationError: TransactionFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false
    @State private var didApplyDefaults = false

    init(mode: TransactionEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: TransactionDraft(occurredAt: defaultDate))
        case .edit(let transaction):
            _draft = State(initialValue: TransactionDraft(transaction: transaction))
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
            TransactionEditorForm(
                draft: $draft,
                accounts: accounts,
                categories: categories,
                isEditing: mode.editedTransaction != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(
                mode.editedTransaction == nil ? "Add transaction" : "Edit transaction"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-transaction")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-transaction")
                }
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-transaction")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its account balance returns to what it was.")
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

    private func applyDefaultsIfNeeded() {
        guard !didApplyDefaults, mode.editedTransaction == nil else {
            return
        }

        didApplyDefaults = true
        TransactionDefaults.apply(
            accountValue: defaultTransactionAccountValue,
            categoryValue: defaultTransactionCategoryValue,
            accounts: accounts,
            categories: categories,
            to: &draft
        )
    }

    /// Switching between income and expense strands a category from the other
    /// direction, which the picker no longer offers. Clearing it keeps the form
    /// honest instead of saving a mismatched pair.
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
            if let editedTransaction = mode.editedTransaction {
                try draft.apply(to: editedTransaction)
            } else {
                let transaction = try draft.makeTransaction(id: UUID(), createdAt: .now)
                modelContext.insert(transaction)
            }
        } catch let error as TransactionFormError {
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
            saveErrorMessage = "Couldn’t save this transaction. Try again."
        }
    }

    private func delete() {
        guard let editedTransaction = mode.editedTransaction else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedTransaction)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this transaction. Try again."
        }
    }
}
