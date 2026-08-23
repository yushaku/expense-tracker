import SwiftData
import SwiftUI

enum SavingsEditorMode: Identifiable {
    case add
    case edit(SavingsDeposit)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let deposit):
            deposit.id.uuidString
        }
    }

    var editedDeposit: SavingsDeposit? {
        switch self {
        case .add:
            nil
        case .edit(let deposit):
            deposit
        }
    }
}

struct SavingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    private let mode: SavingsEditorMode

    @State private var draft: SavingsDraft
    @State private var validationError: SavingsFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false

    init(mode: SavingsEditorMode) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: SavingsDraft(openedAt: .now))
        case .edit(let deposit):
            _draft = State(initialValue: SavingsDraft(deposit: deposit))
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
            SavingsEditorForm(
                draft: $draft,
                accounts: accounts,
                isEditing: mode.editedDeposit != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedDeposit == nil ? "Add savings book" : "Edit savings book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-savings")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-savings")
                }
            }
            .confirmationDialog(
                "Delete this savings book?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-savings")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its principal returns to the linked account's available balance.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var selectedAccount: CashAccount? {
        guard let sourceAccountID = draft.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }
    }

    /// Spendable balance the draft may claim. When editing a deposit already
    /// funded by this account, its own principal is added back so re-saving an
    /// unchanged amount is not reported as an overdraft.
    private func availableBalance(for account: CashAccount) -> Decimal {
        var available = CashBalanceSummary.available(for: account, deposits: deposits)

        if let editedDeposit = mode.editedDeposit,
            editedDeposit.sourceAccountID == account.id
        {
            available += editedDeposit.principal
        }

        return available
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let availableSourceBalance = selectedAccount.map(availableBalance(for:))

        do {
            if let editedDeposit = mode.editedDeposit {
                try draft.apply(
                    to: editedDeposit,
                    availableSourceBalance: availableSourceBalance
                )
            } else {
                let deposit = try draft.makeDeposit(
                    id: UUID(),
                    createdAt: .now,
                    availableSourceBalance: availableSourceBalance
                )
                modelContext.insert(deposit)
            }
        } catch let error as SavingsFormError {
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
            saveErrorMessage = "Couldn’t save this savings book. Try again."
        }
    }

    private func delete() {
        guard let editedDeposit = mode.editedDeposit else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedDeposit)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this savings book. Try again."
        }
    }
}

#if DEBUG
    #Preview("Editor · add") {
        SavingsEditorView(mode: .add)
            .modelContainer(PreviewData.populated)
    }
#endif
