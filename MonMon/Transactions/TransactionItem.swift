import SwiftData
import SwiftUI

struct DeletedTransaction: Equatable, Identifiable {
    let id: UUID
    let kind: TransactionKind
    let amount: Decimal
    let occurredAt: Date
    let note: String
    let accountID: UUID
    let categoryID: UUID?
    let sourceRuleID: UUID?
    let currencyCode: String
    let createdAt: Date
    let sourceImportID: String?
    let incomeAllocationSnapshot: String?

    init(_ transaction: MoneyTransaction) {
        id = transaction.id
        kind = transaction.kind
        amount = transaction.amount
        occurredAt = transaction.occurredAt
        note = transaction.note
        accountID = transaction.accountID
        categoryID = transaction.categoryID
        sourceRuleID = transaction.sourceRuleID
        currencyCode = transaction.currencyCode
        createdAt = transaction.createdAt
        sourceImportID = transaction.sourceImportID
        incomeAllocationSnapshot = transaction.incomeAllocationSnapshot
    }

    func makeTransaction() -> MoneyTransaction {
        MoneyTransaction(
            id: id,
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: note,
            accountID: accountID,
            categoryID: categoryID,
            sourceRuleID: sourceRuleID,
            currencyCode: currencyCode,
            createdAt: createdAt,
            sourceImportID: sourceImportID,
            incomeAllocationSnapshot: incomeAllocationSnapshot
        )
    }
}

enum TransactionDeletion {
    @MainActor
    @discardableResult
    static func delete(
        _ transaction: MoneyTransaction,
        from context: ModelContext
    ) throws -> DeletedTransaction {
        let deleted = DeletedTransaction(transaction)
        context.delete(transaction)

        do {
            try context.save()
            return deleted
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    @discardableResult
    static func restore(
        _ deleted: DeletedTransaction,
        in context: ModelContext
    ) throws -> MoneyTransaction {
        let transaction = deleted.makeTransaction()
        context.insert(transaction)

        do {
            try context.save()
            return transaction
        } catch {
            context.rollback()
            throw error
        }
    }
}

/// What a list opens on behalf of the transaction rows in it.
///
/// A row shows one transaction and carries the swipe that acts on it, but the
/// sheets and follow-up actions belong to the list. Held by the row,
/// each of those is built again for every transaction on screen, and the weight
/// of that tells under the finger: a sheet dragged down stutters, and a
/// dismissed question leaves the list unable to scroll for a moment. A screen
/// keeps one of each instead, and the rows ask for them.
@Observable
final class TransactionActions {
    var detailed: MoneyTransaction?
    var deleteRequested: MoneyTransaction?
    var editing: MoneyTransaction?
    var undoableDeletion: DeletedTransaction?
    var didFailToDelete = false
    var didFailToRestore = false
}

extension View {
    /// Gives the transaction rows below this point the details sheet and the
    /// questions they ask for, and answers a row's request to edit.
    func transactionActions(
        _ actions: TransactionActions,
        undoBottomInset: CGFloat = 20,
        category: @escaping (MoneyTransaction) -> TransactionCategory?,
        account: @escaping (MoneyTransaction) -> CashAccount?,
        onEdit: @escaping (MoneyTransaction) -> Void
    ) -> some View {
        modifier(
            TransactionActionHost(
                actions: actions,
                undoBottomInset: undoBottomInset,
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

    let undoBottomInset: CGFloat
    let category: (MoneyTransaction) -> TransactionCategory?
    let account: (MoneyTransaction) -> CashAccount?
    let onEdit: (MoneyTransaction) -> Void

    /// The editor asked for from within the details sheet waits for the sheet
    /// to close, so the two never fight over who is on screen.
    @State private var editsAfterDetailsDismiss: MoneyTransaction?

    func body(content: Content) -> some View {
        content
            .environment(actions)
            .appSheet(item: $actions.detailed, onDismiss: presentPendingEditor) { transaction in
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
            .overlay(alignment: .bottom) {
                if actions.undoableDeletion != nil {
                    TransactionUndoBanner(undo: restoreLastDeletion)
                        .padding(.horizontal, 20)
                        .padding(.bottom, undoBottomInset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(
                "Couldn’t delete this transaction. Try again.",
                isPresented: $actions.didFailToDelete
            ) {
                Button("OK", role: .cancel) {}
            }
            .alert(
                "Couldn’t restore this transaction. Try adding it again.",
                isPresented: $actions.didFailToRestore
            ) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: actions.deleteRequested) { _, requested in
                guard let requested else {
                    return
                }

                actions.deleteRequested = nil
                delete(requested)
            }
            .onChange(of: actions.editing) { _, requested in
                guard let requested else {
                    return
                }

                actions.editing = nil
                onEdit(requested)
            }
            .task(id: actions.undoableDeletion?.id) {
                guard actions.undoableDeletion != nil else {
                    return
                }

                try? await Task.sleep(for: .seconds(5))

                guard !Task.isCancelled else {
                    return
                }

                withAnimation(.snappy(duration: 0.28)) {
                    actions.undoableDeletion = nil
                }
            }
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
            let deleted = try TransactionDeletion.delete(transaction, from: modelContext)

            withAnimation(.snappy(duration: 0.28)) {
                actions.undoableDeletion = deleted
            }
        } catch {
            actions.didFailToDelete = true
        }
    }

    private func restoreLastDeletion() {
        guard let deleted = actions.undoableDeletion else {
            return
        }

        do {
            try TransactionDeletion.restore(deleted, in: modelContext)

            withAnimation(.snappy(duration: 0.28)) {
                actions.undoableDeletion = nil
            }
        } catch {
            actions.undoableDeletion = nil
            actions.didFailToRestore = true
        }
    }
}

private struct TransactionUndoBanner: View {
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Transaction deleted")
                .font(.subheadline.weight(.medium))

            Spacer(minLength: 8)

            Button("Undo", action: undo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("undo-delete-transaction")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
        .accessibilityIdentifier("transaction-delete-undo-banner")
    }
}

/// The shared transaction interaction used by lists across the app: tap for
/// details, swipe left to edit, and swipe right to delete with a brief Undo.
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
                actions?.deleteRequested = transaction
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
