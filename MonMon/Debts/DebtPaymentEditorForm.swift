import SwiftUI

struct DebtPaymentEditorForm: View {
    @Binding var draft: DebtPaymentDraft

    let debt: Debt
    let outstanding: Decimal
    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: DebtPaymentFormError?
    let saveErrorMessage: String?
    let onFillOutstanding: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    amountCard
                    accountCard
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

    private var tint: Color { debt.direction.tint }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: debt.direction.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(
                    "\(VNDCurrency.format(outstanding)) still outstanding "
                        + "\(preposition) \(debt.counterparty)."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var title: String {
        if isEditing {
            return "Fix what you recorded"
        }

        return debt.direction == .borrowed ? "Paying it back" : "Getting it back"
    }

    private var preposition: String {
        debt.direction == .borrowed ? "to" : "from"
    }

    private var amountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader("Amount", systemImage: "banknote.fill")

                    Spacer()

                    if outstanding > 0 {
                        Button(
                            settleTitle,
                            systemImage: "checkmark.circle.fill",
                            action: onFillOutstanding
                        )
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier("debt-payment-fill-outstanding")
                    }
                }

                HStack(spacing: 12) {
                    Text(signLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(tint)
                        .accessibilityLabel(debt.direction == .borrowed ? "Minus" : "Plus")

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
                    validationMessage(amountErrorMessage, id: "debt-payment-amount-error")
                }

                Text(remainderCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var settleTitle: String {
        debt.direction == .borrowed ? "Pay it all off" : "Settle it"
    }

    private var signLabel: String {
        debt.direction == .borrowed ? "−" : "+"
    }

    /// Live, so the owner can see a payment land exactly on settled before
    /// saving it.
    private var remainderCaption: String {
        guard let amount = VNDCurrency.parse(draft.amountText), amount > 0 else {
            return "VND · This moves one account and lowers what is outstanding by the same amount."
        }

        let remainder = outstanding - amount

        if remainder == 0 {
            return "₫0 — settled."
        }

        if remainder < 0 {
            return "That is more than is still owed."
        }

        return "\(VNDCurrency.format(remainder)) outstanding after this payment."
    }

    private var accountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Cash account", systemImage: "arrow.left.arrow.right")

                if accounts.isEmpty {
                    Text("A payment needs an account. Add one on the Home tab first.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Account")

                        Picker("Account", selection: $draft.accountID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(accounts) { account in
                                Text(account.name)
                                    .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("debt-payment-account")
                    }
                }

                if let accountErrorMessage {
                    validationMessage(accountErrorMessage, id: "debt-payment-account-error")
                }

                Text(
                    debt.direction == .borrowed
                        ? "This account falls by the amount."
                        : "This account rises by the amount."
                )
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
                    fieldLabel("Date")

                    DateField(
                        selection: $draft.occurredAt,
                        accessibilityIdentifier: "debt-payment-date"
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
                        .accessibilityIdentifier("debt-payment-note")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete payment", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-debt-payment")
    }

    @ViewBuilder
    private var amountTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.amountText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("debt-payment-amount")
        #else
            TextField("0", text: $draft.amountText)
                .accessibilityIdentifier("debt-payment-amount")
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
        validationMessage(message, id: "save-debt-payment-error")
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
        case .exceedsOutstanding:
            "That is more than is still owed on this debt."
        case .insufficientSourceBalance:
            "That is more than the account you picked can hand over."
        default:
            nil
        }
    }

    private var accountErrorMessage: String? {
        validationError == .missingAccount ? "Pick the account the money moves through." : nil
    }
}
