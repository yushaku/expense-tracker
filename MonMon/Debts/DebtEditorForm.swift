import SwiftUI

struct DebtEditorForm: View {
    @Binding var draft: DebtDraft

    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: DebtFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    principalCard
                    detailsCard
                    termsCard
                    accountCard

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

    private var tint: Color { draft.direction.tint }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: draft.direction.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(
                    """
                    The account you pick moves by exactly this amount, and your total assets \
                    stay the same.
                    """
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var title: LocalizedStringKey {
        if isEditing {
            return "Fix what you recorded"
        }

        return switch draft.direction {
        case .borrowed:
            "Money you borrowed"
        case .lent:
            "Money you lent"
        }
    }

    private var principalCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Direction", selection: $draft.direction) {
                    ForEach(DebtDirection.allCases, id: \.rawValue) { direction in
                        Text(direction.displayName)
                            .tag(direction)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("debt-direction")

                HStack(spacing: 12) {
                    Text(draft.direction.signLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(tint)
                        .accessibilityLabel(
                            draft.direction == .borrowed ? "Plus" : "Minus"
                        )

                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityHidden(true)

                    principalTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Principal")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let principalErrorMessage {
                    validationMessage(principalErrorMessage, id: "debt-principal-error")
                }

                Text(principalCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var principalCaption: String {
        switch draft.direction {
        case .borrowed:
            """
            VND · Borrowed money lands in the account you pick. Your total assets do not \
            change, because you owe it back.
            """
        case .lent:
            """
            VND · Lent money leaves the account you pick. Your total assets do not change, \
            because it is still owed to you.
            """
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Debt", systemImage: "text.book.closed.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(counterpartyLabel)

                    TextField(counterpartyPrompt, text: $draft.counterparty)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("debt-counterparty")

                    if let counterpartyErrorMessage {
                        validationMessage(
                            counterpartyErrorMessage,
                            id: "debt-counterparty-error"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Opened on")

                    DateField(
                        selection: $draft.openedAt,
                        accessibilityIdentifier: "debt-opened-at"
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
                        .accessibilityIdentifier("debt-note")
                }
            }
        }
    }

    private var counterpartyLabel: LocalizedStringKey {
        draft.direction == .borrowed ? "Who you owe" : "Who owes you"
    }

    private var counterpartyPrompt: LocalizedStringKey {
        draft.direction == .borrowed ? "Who lent it to you" : "Who you lent it to"
    }

    private var termsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Terms", systemImage: "percent")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Annual rate")

                    HStack(spacing: 12) {
                        rateTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()

                        Text("%/year")
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
                    .padding(14)
                    .background(
                        MonMonTheme.field,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                    if let rateErrorMessage {
                        validationMessage(rateErrorMessage, id: "debt-rate-error")
                    }

                    Text("Leave this blank for a loan that charges nothing — most private ones do.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Has a due date", isOn: $draft.hasDueDate)
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("debt-has-due-date")

                    if draft.hasDueDate {
                        DateField(
                            selection: $draft.dueDate,
                            accessibilityIdentifier: "debt-due-date"
                        )
                    }

                    if let dueDateErrorMessage {
                        validationMessage(dueDateErrorMessage, id: "debt-due-date-error")
                    }
                }

                Text(
                    """
                    Interest is an estimate on the original amount, shown but never counted. \
                    What you actually pay is an expense on the Spending screen.
                    """
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var accountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Account", systemImage: "arrow.left.arrow.right")

                if accounts.isEmpty {
                    Text("Add an account on the Home tab to record where the money went.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Account")

                        Picker("Account", selection: $draft.accountID) {
                            Text("Not linked")
                                .tag(UUID?.none)

                            ForEach(accounts) { account in
                                Text(account.name)
                                    .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("debt-account")
                    }
                }

                if let accountErrorMessage {
                    validationMessage(accountErrorMessage, id: "debt-account-error")
                }

                Text(accountCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var accountCaption: String {
        guard draft.accountID != nil else {
            // The case the optional account exists for.
            return """
                Not linked records what you owe without moving any balance — right for a debt you \
                took before you started tracking, whose money is already in an opening balance.
                """
        }

        return switch draft.direction {
        case .borrowed:
            "The principal lands in this account's available balance."
        case .lent:
            "The principal leaves this account's available balance."
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete debt", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-debt")
    }

    @ViewBuilder
    private var principalTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.principalText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("debt-principal")
        #else
            TextField("0", text: $draft.principalText)
                .accessibilityIdentifier("debt-principal")
        #endif
    }

    @ViewBuilder
    private var rateTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.rateText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("debt-rate")
        #else
            TextField("0", text: $draft.rateText)
                .accessibilityIdentifier("debt-rate")
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

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
    }

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
        validationMessage(message, id: "save-debt-error")
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

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var principalErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidPrincipal:
            "Enter a valid amount."
        case .nonPositivePrincipal:
            "Enter an amount greater than zero."
        case .principalBelowPaid:
            "That is less than you have already paid against this debt."
        default:
            nil
        }
    }

    private var counterpartyErrorMessage: LocalizedStringKey? {
        validationError == .emptyCounterparty ? "Name the other side of this debt." : nil
    }

    private var rateErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidRate:
            "Enter a valid rate, or leave it blank for none."
        case .rateOutOfRange:
            "Enter a rate between 0 and 100."
        default:
            nil
        }
    }

    private var dueDateErrorMessage: LocalizedStringKey? {
        validationError == .dueDateBeforeOpening
            ? "The due date cannot be before the day the debt opened." : nil
    }

    private var accountErrorMessage: LocalizedStringKey? {
        validationError == .insufficientSourceBalance
            ? "That is more than the account you picked can hand over." : nil
    }
}
