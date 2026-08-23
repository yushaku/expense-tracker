import SwiftUI

struct TransactionEditorForm: View {
    @Binding var draft: TransactionDraft

    let accounts: [CashAccount]
    let categories: [TransactionCategory]
    let isEditing: Bool
    let validationError: TransactionFormError?
    let saveErrorMessage: String?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    amountCard
                    detailsCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteButton
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
            Image(systemName: draft.kind.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(directionTint, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Fix what you recorded" : "Where the money went")
                    .font(.title3.weight(.semibold))

                Text("The account you pick moves by exactly this amount.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var directionTint: Color {
        draft.kind == .income ? MonMonTheme.gain : MonMonTheme.danger
    }

    private var amountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Direction", selection: $draft.kind) {
                    ForEach(TransactionKind.allCases, id: \.rawValue) {
                        Text($0.displayName)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("transaction-kind")

                HStack(spacing: 12) {
                    Text(draft.kind.signLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(directionTint)
                        .accessibilityLabel(
                            draft.kind == .income ? "Plus" : "Minus"
                        )

                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityHidden(true)

                    amountTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Amount")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let amountErrorMessage {
                    validationMessage(amountErrorMessage, id: "transaction-amount-error")
                }

                Text("VND · Enter what you spent or received, never a negative number.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Details", systemImage: "list.bullet")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Category")

                    if matchingCategories.isEmpty {
                        Text(missingCategoryNotice)
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    } else {
                        Picker("Category", selection: $draft.categoryID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(matchingCategories) { category in
                                Text(category.name)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("transaction-category")
                    }

                    if let categoryErrorMessage {
                        validationMessage(categoryErrorMessage, id: "transaction-category-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Account")

                    if accounts.isEmpty {
                        Text("No account yet. Add one on the Home tab first.")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    } else {
                        Picker("Account", selection: $draft.accountID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(accounts) { account in
                                Text(account.name)
                                    .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("transaction-account")
                    }

                    if let accountErrorMessage {
                        validationMessage(accountErrorMessage, id: "transaction-account-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Date")

                    DateField(
                        selection: $draft.occurredAt,
                        accessibilityIdentifier: "transaction-date"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Note")

                    TextField("Optional", text: $draft.note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("transaction-note")
                }
            }
        }
    }

    private var missingCategoryNotice: String {
        "No \(draft.kind.displayName.lowercased()) category yet. "
            + "Add one from the Categories button."
    }

    /// A category only appears for the direction it was created for, so an
    /// expense can never be filed under Salary.
    private var matchingCategories: [TransactionCategory] {
        categories.filter { $0.kind == draft.kind }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete transaction", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.danger)
        .background(
            MonMonTheme.danger.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
        }
        .accessibilityIdentifier("delete-transaction")
    }

    @ViewBuilder
    private var amountTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.amountText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("transaction-amount")
        #else
            TextField("0", text: $draft.amountText)
                .accessibilityIdentifier("transaction-amount")
        #endif
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
    }

    private func errorBanner(_ message: String) -> some View {
        validationMessage(message, id: "save-transaction-error")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
            }
    }

    private func validationMessage(_ message: String, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var amountErrorMessage: String? {
        switch validationError {
        case .invalidAmount:
            "Enter a valid amount."
        case .nonPositiveAmount:
            "Enter an amount greater than zero."
        default:
            nil
        }
    }

    private var accountErrorMessage: String? {
        validationError == .missingAccount ? "Pick the account this money moved through." : nil
    }

    private var categoryErrorMessage: String? {
        validationError == .missingCategory ? "Pick a category." : nil
    }
}
