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
                .frame(minWidth: 400, minHeight: 360)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Account name", text: $draft.name)
                        .accessibilityIdentifier("account-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage, id: "account-name-error")
                    }

                    Picker("Type", selection: $draft.kind) {
                        ForEach(CashAccountKind.allCases, id: \.rawValue) { kind in
                            Text(kind.displayName)
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("account-kind")
                }

                Section {
                    #if os(iOS)
                        TextField("0", text: $draft.openingBalanceText)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("opening-balance")
                    #else
                        TextField("0", text: $draft.openingBalanceText)
                            .accessibilityIdentifier("opening-balance")
                    #endif

                    if let balanceErrorMessage {
                        validationMessage(balanceErrorMessage, id: "opening-balance-error")
                    }
                } header: {
                    Text("Opening balance")
                } footer: {
                    Text("Amount in VND")
                }

                if let saveErrorMessage {
                    Section {
                        validationMessage(saveErrorMessage, id: "save-account-error")
                    }
                }
            }
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
                    .accessibilityIdentifier("save-account")
                }
            }
        }
    }

    private var nameErrorMessage: String? {
        guard validationError == .emptyName else { return nil }
        return "Enter an account name."
    }

    private var balanceErrorMessage: String? {
        switch validationError {
        case .invalidOpeningBalance:
            "Enter a valid balance."
        case .negativeOpeningBalance:
            "Balance cannot be negative."
        default:
            nil
        }
    }

    private func validationMessage(_ message: String, id: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityIdentifier(id)
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
