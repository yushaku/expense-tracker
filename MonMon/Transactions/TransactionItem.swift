import SwiftData
import SwiftUI

enum TransactionDeletion {
    @MainActor
    static func delete(_ transaction: MoneyTransaction, from context: ModelContext) throws {
        context.delete(transaction)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

/// The shared transaction interaction used by lists across the app: tap for
/// details, swipe left to edit, and swipe right to delete with confirmation.
struct TransactionItem: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: MoneyTransaction
    let category: TransactionCategory?
    let account: CashAccount?
    let showsDate: Bool
    let accessibilityIdentifier: String
    let onEdit: () -> Void

    @State private var isShowingDetails = false
    @State private var editsAfterDetailsDismiss = false
    @State private var isConfirmingDelete = false
    @State private var isShowingDeleteError = false

    init(
        transaction: MoneyTransaction,
        category: TransactionCategory?,
        account: CashAccount?,
        showsDate: Bool = true,
        accessibilityIdentifier: String,
        onEdit: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.category = category
        self.account = account
        self.showsDate = showsDate
        self.accessibilityIdentifier = accessibilityIdentifier
        self.onEdit = onEdit
    }

    var body: some View {
        TransactionSwipeRow(
            onTap: {
                isShowingDetails = true
            },
            onEdit: onEdit,
            onDelete: {
                isConfirmingDelete = true
            }
        ) {
            TransactionCard(
                transaction: transaction,
                category: category,
                account: account,
                showsDate: showsDate
            )
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(
            "Opens transaction details. Swipe left to edit or right to delete."
        )
        .sheet(isPresented: $isShowingDetails, onDismiss: presentPendingEditor) {
            TransactionDetailSheet(
                transaction: transaction,
                category: category,
                account: account,
                onEdit: {
                    editsAfterDetailsDismiss = true
                    isShowingDetails = false
                },
                onDelete: delete
            )
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteFromSwipeAction()
            }
            .accessibilityIdentifier("confirm-delete-transaction")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its account balance returns to what it was.")
        }
        .alert(
            "Couldn’t delete this transaction. Try again.",
            isPresented: $isShowingDeleteError
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private func presentPendingEditor() {
        guard editsAfterDetailsDismiss else {
            return
        }

        editsAfterDetailsDismiss = false
        onEdit()
    }

    private func deleteFromSwipeAction() {
        do {
            try delete()
        } catch {
            isShowingDeleteError = true
        }
    }

    private func delete() throws {
        try TransactionDeletion.delete(transaction, from: modelContext)
    }
}
