import SwiftUI

struct AccountEditorForm: View {
    @Binding var draft: AccountDraft

    let isEditing: Bool
    let canDelete: Bool
    let deleteBlockedReason: String?
    let validationError: AccountFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    accountDetailsCard
                    openingBalanceCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteSection
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: isEditing ? "pencil" : "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Keep this account honest" : "Give your money a home")
                    .font(.title3.weight(.semibold))

                Text(
                    isEditing
                        ? "Update its name, type, or balance."
                        : "Start with the balance available today."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            deleteButton

            if let deleteBlockedReason {
                Text(deleteBlockedReason)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("delete-account-blocked")
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete account", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
        .foregroundStyle(canDelete ? MonMonTheme.danger : MonMonTheme.textMuted)
        .background(
            (canDelete ? MonMonTheme.danger : MonMonTheme.textMuted).opacity(0.14),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    (canDelete ? MonMonTheme.danger : MonMonTheme.textMuted).opacity(0.35),
                    lineWidth: 1
                )
        }
        .accessibilityIdentifier("delete-account")
    }

    private var accountDetailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Account details", systemImage: "wallet.bifold.fill")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account name")
                        .font(.subheadline.weight(.medium))

                    TextField("Account name", text: $draft.name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("account-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage, id: "account-name-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account type")
                        .font(.subheadline.weight(.medium))

                    Picker("Account type", selection: $draft.kind) {
                        ForEach(CashAccountKind.allCases, id: \.rawValue) {
                            Text($0.displayName)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("account-kind")
                }
            }
        }
    }

    private var openingBalanceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Opening balance", systemImage: "banknote.fill")

                HStack(spacing: 12) {
                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)

                    balanceTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Opening balance")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let balanceErrorMessage {
                    validationMessage(balanceErrorMessage, id: "opening-balance-error")
                }

                Text(balanceHint)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var balanceTextField: some View {
        #if os(iOS)
            // A credit card balance can be negative, and `.numberPad` has no
            // minus key, so that kind needs the punctuation keyboard.
            TextField("0", text: $draft.openingBalanceText)
                .keyboardType(
                    draft.kind.allowsNegativeBalance ? .numbersAndPunctuation : .numberPad
                )
                .accessibilityIdentifier("opening-balance")
        #else
            TextField("0", text: $draft.openingBalanceText)
                .accessibilityIdentifier("opening-balance")
        #endif
    }

    private var balanceHint: LocalizedStringKey {
        draft.kind.allowsNegativeBalance
            ? "VND · Enter a negative amount for money you owe."
            : "VND · This becomes the current balance for this account."
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
        validationMessage(message, id: "save-account-error")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(MonMonTheme.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
            }
    }

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var nameErrorMessage: LocalizedStringKey? {
        guard validationError == .emptyName else { return nil }
        return "Enter an account name."
    }

    private var balanceErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidOpeningBalance:
            "Enter a valid balance."
        case .negativeOpeningBalance:
            "Only a credit card can hold a negative balance."
        default:
            nil
        }
    }
}

#if DEBUG
    private struct AccountEditorFormPreview: View {
        @State var draft: AccountDraft
        var isEditing = false
        var canDelete = false
        var deleteBlockedReason: String?
        var validationError: AccountFormError?
        var saveErrorMessage: LocalizedStringKey?

        var body: some View {
            NavigationStack {
                AccountEditorForm(
                    draft: $draft,
                    isEditing: isEditing,
                    canDelete: canDelete,
                    deleteBlockedReason: deleteBlockedReason,
                    validationError: validationError,
                    saveErrorMessage: saveErrorMessage,
                    onDelete: {}
                )
                .navigationTitle(isEditing ? "Edit account" : "Add account")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    #Preview("Form · empty") {
        AccountEditorFormPreview(draft: AccountDraft())
    }

    #Preview("Form · filled") {
        AccountEditorFormPreview(
            draft: AccountDraft(name: "Techcombank", kind: .bank, openingBalanceText: "48.900.000")
        )
    }

    #Preview("Form · edit deletable") {
        AccountEditorFormPreview(
            draft: AccountDraft(name: "Old wallet", kind: .cash, openingBalanceText: "0"),
            isEditing: true,
            canDelete: true
        )
    }

    #Preview("Form · edit blocked") {
        AccountEditorFormPreview(
            draft: AccountDraft(
                name: "Visa credit",
                kind: .credit,
                openingBalanceText: "-5.200.000"
            ),
            isEditing: true,
            deleteBlockedReason: "Set the balance to 0 before deleting this account."
        )
    }

    #Preview("Form · errors") {
        AccountEditorFormPreview(
            draft: AccountDraft(name: "", kind: .cash, openingBalanceText: "-10"),
            validationError: .negativeOpeningBalance,
            saveErrorMessage: "Couldn’t save this account. Try again."
        )
    }
#endif
