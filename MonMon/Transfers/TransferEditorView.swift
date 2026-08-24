import SwiftData
import SwiftUI

enum TransferEditorMode: Identifiable {
    case add
    case edit(AccountTransfer)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let transfer):
            transfer.id.uuidString
        }
    }

    var editedTransfer: AccountTransfer? {
        switch self {
        case .add:
            nil
        case .edit(let transfer):
            transfer
        }
    }
}

struct TransferEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    private let mode: TransferEditorMode

    @State private var draft: TransferDraft
    @State private var validationError: TransferFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false

    init(mode: TransferEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: TransferDraft(occurredAt: defaultDate))
        case .edit(let transfer):
            _draft = State(initialValue: TransferDraft(transfer: transfer))
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
            TransferEditorForm(
                draft: $draft,
                accounts: accounts,
                isEditing: mode.editedTransfer != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onSwap: { draft.swapEnds() },
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedTransfer == nil ? "Add transfer" : "Edit transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-transfer")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-transfer")
                }
            }
            .confirmationDialog(
                "Delete this transfer?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-transfer")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Both account balances return to what they were.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var sourceAccount: CashAccount? {
        guard let sourceAccountID = draft.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }
    }

    /// What the source account may hand over. A credit card is allowed to go
    /// below zero, so nothing caps it; every other account is capped at its
    /// spendable balance. When editing, this transfer's own amount is added
    /// back so re-saving an unchanged amount is not reported as an overdraft.
    private var availableSourceBalance: Decimal? {
        guard let sourceAccount, !sourceAccount.kind.allowsNegativeBalance else {
            return nil
        }

        var available = CashBalanceSummary.available(
            for: sourceAccount,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )

        if let editedTransfer = mode.editedTransfer,
            editedTransfer.sourceAccountID == sourceAccount.id
        {
            available += editedTransfer.amount
        }

        return available
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let sourceBalance = availableSourceBalance

        do {
            if let editedTransfer = mode.editedTransfer {
                try draft.apply(to: editedTransfer, availableSourceBalance: sourceBalance)
            } else {
                let transfer = try draft.makeTransfer(
                    id: UUID(),
                    createdAt: .now,
                    availableSourceBalance: sourceBalance
                )
                modelContext.insert(transfer)
            }
        } catch let error as TransferFormError {
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
            saveErrorMessage = "Couldn’t save this transfer. Try again."
        }
    }

    private func delete() {
        guard let editedTransfer = mode.editedTransfer else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedTransfer)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this transfer. Try again."
        }
    }
}

#if DEBUG
    #Preview("Transfer editor · add") {
        TransferEditorView(mode: .add)
            .modelContainer(PreviewData.populated)
    }
#endif
