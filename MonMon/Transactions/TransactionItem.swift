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

/// What a list opens on behalf of the transaction rows in it.
///
/// A row shows one transaction and carries the swipe that acts on it, but the
/// sheet and the questions that follow belong to the list. Held by the row,
/// each of those is built again for every transaction on screen, and the weight
/// of that tells under the finger: a sheet dragged down stutters, and a
/// dismissed question leaves the list unable to scroll for a moment. A screen
/// keeps one of each instead, and the rows ask for them.
@Observable
final class TransactionActions {
    var detailed: MoneyTransaction?
    var deleting: MoneyTransaction?
    var editing: MoneyTransaction?
    var didFailToDelete = false
}

extension View {
    /// Gives the transaction rows below this point the details sheet and the
    /// questions they ask for, and answers a row's request to edit.
    func transactionActions(
        _ actions: TransactionActions,
        category: @escaping (MoneyTransaction) -> TransactionCategory?,
        account: @escaping (MoneyTransaction) -> CashAccount?,
        onEdit: @escaping (MoneyTransaction) -> Void
    ) -> some View {
        modifier(
            TransactionActionHost(
                actions: actions,
                category: category,
                account: account,
                onEdit: onEdit
            )
        )
    }
}

private struct TransactionActionHost: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Bindable var actions: TransactionActions

    let category: (MoneyTransaction) -> TransactionCategory?
    let account: (MoneyTransaction) -> CashAccount?
    let onEdit: (MoneyTransaction) -> Void

    /// The editor asked for from within the details sheet waits for the sheet
    /// to close, so the two never fight over who is on screen.
    @State private var editsAfterDetailsDismiss: MoneyTransaction?

    func body(content: Content) -> some View {
        content
            .environment(actions)
            .sheet(item: $actions.detailed, onDismiss: presentPendingEditor) { transaction in
                TransactionDetailSheet(
                    transaction: transaction,
                    category: category(transaction),
                    account: account(transaction),
                    onEdit: {
                        editsAfterDetailsDismiss = transaction
                        actions.detailed = nil
                    },
                    onDelete: {
                        try TransactionDeletion.delete(transaction, from: modelContext)
                    }
                )
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: isAskingBeforeDeleting,
                titleVisibility: .visible,
                presenting: actions.deleting
            ) { transaction in
                Button("Delete", role: .destructive) {
                    delete(transaction)
                }
                .accessibilityIdentifier("confirm-delete-transaction")

                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Its account balance returns to what it was.")
            }
            .alert(
                "Couldn’t delete this transaction. Try again.",
                isPresented: $actions.didFailToDelete
            ) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: actions.editing) { _, requested in
                guard let requested else {
                    return
                }

                actions.editing = nil
                onEdit(requested)
            }
    }

    private var isAskingBeforeDeleting: Binding<Bool> {
        Binding(
            get: { actions.deleting != nil },
            set: { isAsking in
                if !isAsking {
                    actions.deleting = nil
                }
            }
        )
    }

    private func presentPendingEditor() {
        guard let transaction = editsAfterDetailsDismiss else {
            return
        }

        editsAfterDetailsDismiss = nil
        onEdit(transaction)
    }

    private func delete(_ transaction: MoneyTransaction) {
        do {
            try TransactionDeletion.delete(transaction, from: modelContext)
        } catch {
            actions.didFailToDelete = true
        }
    }
}

/// The shared transaction interaction used by lists across the app: tap for
/// details, swipe left to edit, and swipe right to delete with confirmation.
///
/// The row asks; the list its screen set up with `transactionActions` answers.
struct TransactionItem: View {
    @Environment(TransactionActions.self) private var actions: TransactionActions?

    let transaction: MoneyTransaction
    let category: TransactionCategory?
    let account: CashAccount?
    let showsDate: Bool
    let accessibilityIdentifier: String

    init(
        transaction: MoneyTransaction,
        category: TransactionCategory?,
        account: CashAccount?,
        showsDate: Bool = true,
        accessibilityIdentifier: String
    ) {
        self.transaction = transaction
        self.category = category
        self.account = account
        self.showsDate = showsDate
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        TransactionSwipeRow(
            onTap: {
                actions?.detailed = transaction
            },
            onEdit: {
                actions?.editing = transaction
            },
            onDelete: {
                actions?.deleting = transaction
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
    }
}
