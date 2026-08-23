import SwiftData
import SwiftUI

enum CategoryEditorMode: Identifiable {
    case add
    case edit(TransactionCategory)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let category):
            category.id.uuidString
        }
    }

    var editedCategory: TransactionCategory? {
        switch self {
        case .add:
            nil
        case .edit(let category):
            category
        }
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    private let mode: CategoryEditorMode

    @State private var draft: CategoryDraft
    @State private var validationError: CategoryFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false
    @State private var isReassigning = false

    init(mode: CategoryEditorMode) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: CategoryDraft())
        case .edit(let category):
            _draft = State(initialValue: CategoryDraft(category: category))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 600)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            CategoryEditorForm(
                draft: $draft,
                isEditing: mode.editedCategory != nil,
                usageCount: usageCount,
                canDelete: canDelete,
                deleteBlockedReason: deleteBlockedReason,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: startDelete
            )
            .navigationTitle(mode.editedCategory == nil ? "Add category" : "Edit category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-category")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-category")
                }
            }
            .confirmationDialog(
                "Delete this category?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-category")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("No transaction uses it, so nothing else changes.")
            }
            .sheet(isPresented: $isReassigning) {
                if let editedCategory = mode.editedCategory {
                    CategoryReassignView(
                        category: editedCategory,
                        usageCount: usageCount,
                        replacements: replacements,
                        errorMessage: saveErrorMessage,
                        onConfirm: { replacement in
                            reassignAndDelete(to: replacement)
                        }
                    )
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var usageCount: Int {
        guard let editedCategory = mode.editedCategory else {
            return 0
        }

        return TransactionSummary.count(for: editedCategory, transactions: transactions)
    }

    /// Categories the transactions could move to: same direction, not this one.
    private var replacements: [TransactionCategory] {
        guard let editedCategory = mode.editedCategory else {
            return []
        }

        return categories.filter {
            $0.id != editedCategory.id && $0.kind == editedCategory.kind
        }
    }

    /// A category in use can still be deleted, but only through the reassign
    /// sheet, and only when somewhere else exists to move its transactions to.
    private var canDelete: Bool {
        guard mode.editedCategory != nil else {
            return false
        }

        return usageCount == 0 || !replacements.isEmpty
    }

    private var deleteBlockedReason: String? {
        guard mode.editedCategory != nil, !canDelete else {
            return nil
        }

        return "Add another \(draft.kind.displayName.lowercased()) category first, "
            + "so these transactions have somewhere to go."
    }

    private func startDelete() {
        saveErrorMessage = nil

        if usageCount == 0 {
            isConfirmingDelete = true
        } else {
            isReassigning = true
        }
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let editedCategory = mode.editedCategory {
                try draft.apply(to: editedCategory, existing: categories)
            } else {
                let category = try draft.makeCategory(
                    id: UUID(),
                    createdAt: .now,
                    existing: categories
                )
                modelContext.insert(category)
            }
        } catch let error as CategoryFormError {
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
            saveErrorMessage = "Couldn’t save this category. Try again."
        }
    }

    private func delete() {
        guard let editedCategory = mode.editedCategory else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedCategory)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this category. Try again."
        }
    }

    /// Moves every affected transaction and deletes the category in one save, so
    /// a failure cannot leave transactions pointing at a category that is gone.
    private func reassignAndDelete(to replacement: TransactionCategory) {
        guard let editedCategory = mode.editedCategory else {
            return
        }

        saveErrorMessage = nil

        let affected = transactions.filter { $0.categoryID == editedCategory.id }
        for transaction in affected {
            transaction.categoryID = replacement.id
        }

        modelContext.delete(editedCategory)

        do {
            try modelContext.save()
            isReassigning = false
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t move these transactions. Try again."
        }
    }
}
