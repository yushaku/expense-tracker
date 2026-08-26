import SwiftData
import SwiftUI

enum TransactionEditorMode: Identifiable {
    case add
    case edit(MoneyTransaction)
    case review(PendingTransactionCapture)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let transaction):
            transaction.id.uuidString
        case .review(let capture):
            "review-\(capture.id.uuidString)"
        }
    }

    var editedTransaction: MoneyTransaction? {
        switch self {
        case .add:
            nil
        case .edit(let transaction):
            transaction
        case .review:
            nil
        }
    }

    var pendingCapture: PendingTransactionCapture? {
        guard case .review(let capture) = self else {
            return nil
        }
        return capture
    }

    var canDelete: Bool {
        editedTransaction != nil || pendingCapture != nil
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
    @AppStorage(TransactionDefaults.incomeCategoryStorageKey)
    private var defaultTransactionIncomeCategoryValue = ""

    private let mode: TransactionEditorMode

    @State private var draft: TransactionDraft
    @State private var validationError: TransactionFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var didApplyDefaults = false

    init(mode: TransactionEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: TransactionDraft(occurredAt: defaultDate))
        case .edit(let transaction):
            _draft = State(initialValue: TransactionDraft(transaction: transaction))
        case .review(let capture):
            _draft = State(initialValue: capture.draft)
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
                isEditing: mode.canDelete,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(navigationTitle)
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
                deleteConfirmationTitle,
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-transaction")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteConfirmationMessage)
            }
            .onChange(of: draft.kind) { _, _ in
                applyDefaultCategoryIfDirectionChanged()
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
        if mode.pendingCapture != nil {
            applyMissingDefaults()
            return
        }

        TransactionDefaults.apply(
            accountValue: defaultTransactionAccountValue,
            categoryValue: defaultTransactionCategoryValue,
            accounts: accounts,
            categories: categories,
            to: &draft
        )
    }

    private func applyMissingDefaults() {
        if draft.accountID == nil {
            draft.accountID = TransactionDefaults.resolveAccountID(
                defaultTransactionAccountValue,
                accounts: accounts
            )
        }
        if draft.categoryID == nil {
            draft.categoryID = TransactionDefaults.categoryID(
                for: draft.kind,
                expenseValue: defaultTransactionCategoryValue,
                incomeValue: defaultTransactionIncomeCategoryValue,
                categories: categories
            )
        }
    }

    /// Switching between income and expense strands a category from the other
    /// direction, which the picker no longer offers. The new direction's own
    /// default takes its place, so the form stays filled in rather than emptying
    /// itself, and falls back to nothing when that direction has no default.
    private func applyDefaultCategoryIfDirectionChanged() {
        let stillOffered = draft.categoryID.map { categoryID in
            categories.contains { $0.id == categoryID && $0.kind == draft.kind }
        }

        guard stillOffered != true else {
            return
        }

        draft.categoryID = TransactionDefaults.categoryID(
            for: draft.kind,
            expenseValue: defaultTransactionCategoryValue,
            incomeValue: defaultTransactionIncomeCategoryValue,
            categories: categories
        )
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
                if let pendingCapture = mode.pendingCapture {
                    modelContext.delete(pendingCapture)
                }
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
        if let editedTransaction = mode.editedTransaction {
            modelContext.delete(editedTransaction)
        } else if let pendingCapture = mode.pendingCapture {
            modelContext.delete(pendingCapture)
        } else {
            return
        }

        saveErrorMessage = nil

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this transaction. Try again."
        }
    }

    private var navigationTitle: LocalizedStringKey {
        if mode.pendingCapture != nil {
            return "Review transaction"
        }
        return mode.editedTransaction == nil ? "Add transaction" : "Edit transaction"
    }

    private var deleteConfirmationTitle: LocalizedStringKey {
        mode.pendingCapture == nil ? "Delete this transaction?" : "Delete this capture?"
    }

    private var deleteConfirmationMessage: LocalizedStringKey {
        mode.pendingCapture == nil
            ? "Its account balance returns to what it was."
            : "The spoken entry will be discarded without changing totals."
    }
}
