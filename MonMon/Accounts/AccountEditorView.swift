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

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    private let mode: AccountEditorMode

    @State private var draft: AccountDraft
    @State private var validationError: AccountFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    /// Where this account's records land when it goes. Nil until the owner
    /// picks, because moving somebody's whole history is not a default worth
    /// guessing at.
    @State private var moveDestinationID: UUID?
    /// How many records name this account. Read once when the sheet opens
    /// rather than on every redraw: nothing can write to the store while it is
    /// in front, and the count walks ten tables.
    @State private var linkedRecordCount = 0

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
                requiresDestination: requiresDestination,
                moveDestinations: moveDestinations,
                moveDestinationID: $moveDestinationID,
                linkedRecordCount: linkedRecordCount,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .task {
                guard let editedAccount = mode.editedAccount else {
                    return
                }

                linkedRecordCount = AccountMerge.linkedRecordCount(
                    for: editedAccount,
                    in: modelContext
                )
            }
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
                Text(deleteConfirmationMessage)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// Deletion is offered for every account but one, because an account that
    /// still holds records can hand them over instead of blocking. What it
    /// cannot do is take them with it: `AccountMerge` moves every record and
    /// the opening balance to another account first.
    private var canDelete: Bool {
        guard let editedAccount = mode.editedAccount else {
            return false
        }

        // The anchor every account-shaped foreign key defaults to. Deleting it
        // would leave those defaults naming nothing, which is the one state
        // `AccountSeed` exists to prevent.
        guard !AccountSeed.isUnassigned(editedAccount) else {
            return false
        }

        return !requiresDestination || moveDestination != nil
    }

    /// Whether this account has anything to hand over. Its balance counts as
    /// much as its records: deleting an account holding money would take the
    /// money with it.
    private var requiresDestination: Bool {
        guard let editedAccount = mode.editedAccount else {
            return false
        }

        return linkedRecordCount > 0 || editedAccount.openingBalance != 0
    }

    /// Every other account, in the order the accounts screen lists them. The
    /// unassigned one is in here on purpose: it is where money with nowhere
    /// else to go belongs.
    private var moveDestinations: [CashAccount] {
        guard let editedAccount = mode.editedAccount else {
            return []
        }

        return accounts.filter { $0.id != editedAccount.id }
    }

    private var moveDestination: CashAccount? {
        moveDestinations.first { $0.id == moveDestinationID }
    }

    private var deleteBlockedReason: LocalizedStringKey? {
        guard let editedAccount = mode.editedAccount, !canDelete else {
            return nil
        }

        if AccountSeed.isUnassigned(editedAccount) {
            return """
                This is where records with no account of their own land, so it \
                stays.
                """
        }

        if moveDestinations.isEmpty {
            return "Add another account first, so this one has somewhere to move its records."
        }

        return "Pick where this account's records should go."
    }

    private var deleteConfirmationMessage: LocalizedStringKey {
        guard let destination = moveDestination else {
            return "It disappears from your cash overview. This cannot be undone."
        }

        return """
            \(linkedRecordCount) records and this account's balance move to \
            \(destination.name). This cannot be undone.
            """
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

        do {
            if let destination = moveDestination {
                try AccountMerge.move(
                    from: editedAccount,
                    to: destination,
                    in: modelContext
                )
            } else {
                modelContext.delete(editedAccount)
                try modelContext.save()
            }
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
