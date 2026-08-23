import SwiftData
import SwiftUI

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var draft = AccountDraft()
    @State private var validationError: AccountFormError?
    @State private var saveErrorMessage: String?

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
            AddAccountForm(
                draft: $draft,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage
            )
            .navigationTitle("Add account")
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
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let account: CashAccount
        do {
            account = try draft.makeAccount(id: UUID(), createdAt: .now)
        } catch let error as AccountFormError {
            validationError = error
            return
        } catch {
            saveErrorMessage = "Something went wrong. Try again."
            return
        }

        modelContext.insert(account)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save this account. Try again."
        }
    }
}
