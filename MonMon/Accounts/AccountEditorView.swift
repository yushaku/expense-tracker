import SwiftData
import SwiftUI

enum AccountEditorMode: Identifiable {
    case add
    case edit(CashAccount)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let account):
            account.id.uuidString
        }
    }

    var editedAccount: CashAccount? {
        switch self {
        case .add:
            nil
        case .edit(let account):
            account
        }
    }
}

struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    private let mode: AccountEditorMode

    @State private var draft: AccountDraft
    @State private var validationError: AccountFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false

    init(mode: AccountEditorMode) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: AccountDraft())
        case .edit(let account):
            _draft = State(initialValue: AccountDraft(account: account))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 440, minHeight: 520)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            AccountEditorForm(
                draft: $draft,
                isEditing: mode.editedAccount != nil,
                canDelete: canDelete,
                deleteBlockedReason: deleteBlockedReason,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedAccount == nil ? "Add account" : "Edit account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-add-account")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-account")
                }
            }
            .confirmationDialog(
                "Delete this account?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-account")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It disappears from your cash overview. This cannot be undone.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// An account may only be removed once it holds nothing and nothing points
    /// at it. A zero available balance rules out a savings deposit or a fund
    /// holding, but not a transaction: an account with 100 in and 100 out sits
    /// at zero while still owning two records, so the count is checked too.
    private var canDelete: Bool {
        guard let editedAccount = mode.editedAccount else {
            return false
        }

        let isEmpty =
            CashBalanceSummary.available(
                for: editedAccount,
                deposits: deposits,
                holdings: holdings,
                transactions: transactions
            ) == 0

        return isEmpty && transactionCount == 0
    }

    private var transactionCount: Int {
        guard let editedAccount = mode.editedAccount else {
            return 0
        }

        return TransactionSummary.count(for: editedAccount, transactions: transactions)
    }

    private var deleteBlockedReason: String? {
        guard let editedAccount = mode.editedAccount, !canDelete else {
            return nil
        }

        let fundedAmount = CashBalanceSummary.fundedAmount(
            for: editedAccount,
            deposits: deposits,
            holdings: holdings
        )

        if fundedAmount > 0 {
            return "This account still funds savings books or funds. Move them first."
        }

        if transactionCount > 0 {
            let noun = transactionCount == 1 ? "transaction" : "transactions"
            return "This account still has \(transactionCount) \(noun). Delete them first."
        }

        return "Set the balance to 0 before deleting this account."
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let editedAccount = mode.editedAccount {
                try draft.apply(to: editedAccount)
            } else {
                let account = try draft.makeAccount(id: UUID(), createdAt: .now)
                modelContext.insert(account)
            }
        } catch let error as AccountFormError {
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
            saveErrorMessage = "Couldn’t save this account. Try again."
        }
    }

    private func delete() {
        guard let editedAccount = mode.editedAccount, canDelete else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedAccount)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this account. Try again."
        }
    }
}

#if DEBUG
    #Preview("Editor · add") {
        AccountEditorView(mode: .add)
            .modelContainer(PreviewData.populated)
    }
#endif
