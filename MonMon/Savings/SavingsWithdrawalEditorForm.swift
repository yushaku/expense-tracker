import SwiftUI

struct SavingsWithdrawalEditorForm: View {
    @Binding var draft: SavingsWithdrawalDraft

    let deposit: SavingsDeposit
    let remainingPrincipal: Decimal
    let suggestedMaturityAmount: Decimal
    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: SavingsWithdrawalFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onWithdrawEverything: () -> Void
    let onUseMaturityEstimate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    principalCard
                    receivedCard
                    accountCard
                    detailsCard

                    if let saveErrorMessage {
                        validationMessage(saveErrorMessage, id: "save-savings-withdrawal-error")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                MonMonTheme.danger.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
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
            Image(systemName: "arrow.down.to.line.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.savings, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(deposit.name)
                    .font(.title3.weight(.semibold))

                Text("Record what the bank actually paid into your account.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var principalCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader("Principal withdrawn", systemImage: "banknote.fill")

                    Spacer()

                    Button("Withdraw all") {
                        onWithdrawEverything()
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(remainingPrincipal <= 0)
                    .accessibilityIdentifier("savings-withdraw-all")
                }

                currencyField(
                    text: $draft.principalText,
                    label: "Principal withdrawn",
                    identifier: "savings-withdrawal-principal"
                )

                if let principalErrorMessage {
                    validationMessage(
                        principalErrorMessage,
                        id: "savings-withdrawal-principal-error"
                    )
                }

                Text(
                    "Up to \(VNDCurrency.format(remainingPrincipal)) remains available to withdraw."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var receivedCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader("Amount received", systemImage: "arrow.down.circle.fill")

                    Spacer()

                    Button("Use maturity estimate") {
                        onUseMaturityEstimate()
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("savings-use-maturity-estimate")
                }

                currencyField(
                    text: $draft.amountReceivedText,
                    label: "Amount received",
                    identifier: "savings-withdrawal-received"
                )

                if let receivedErrorMessage {
                    validationMessage(
                        receivedErrorMessage,
                        id: "savings-withdrawal-received-error"
                    )
                }

                if let difference {
                    HStack {
                        Text(difference >= 0 ? "Interest received" : "Loss on withdrawal")
                            .foregroundStyle(MonMonTheme.textSecondary)

                        Spacer()

                        Text(VNDCurrency.format(abs(difference)))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(
                                difference >= 0 ? MonMonTheme.gain : MonMonTheme.danger
                            )
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }

                Text(
                    "Maturity estimate for the remaining book: \(VNDCurrency.format(suggestedMaturityAmount))."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var accountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Where the money went", systemImage: "building.columns.fill")

                if accounts.isEmpty {
                    Text(
                        "A withdrawal needs an account to receive the money. Add one on the Home tab first."
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    Picker("Account", selection: $draft.destinationAccountID) {
                        Text("Choose")
                            .tag(UUID?.none)

                        ForEach(accounts) { account in
                            Text(account.name)
                                .tag(UUID?.some(account.id))
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("savings-withdrawal-account")
                }

                if validationError == .missingAccount {
                    validationMessage(
                        "Choose the account that received the money.",
                        id: "savings-withdrawal-account-error"
                    )
                }

                Text("The selected account rises by the amount actually received.")
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
                    Text("Withdrawal date")
                        .font(.subheadline.weight(.medium))

                    DateField(
                        selection: $draft.withdrawnAt,
                        accessibilityIdentifier: "savings-withdrawal-date"
                    )

                    if let dateErrorMessage {
                        validationMessage(dateErrorMessage, id: "savings-withdrawal-date-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.subheadline.weight(.medium))

                    TextField("Optional", text: $draft.note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("savings-withdrawal-note")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete withdrawal", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-savings-withdrawal")
    }

    private func currencyField(
        text: Binding<String>,
        label: LocalizedStringKey,
        identifier: String
    ) -> some View {
        HStack(spacing: 12) {
            Text("₫")
                .font(.title2.weight(.bold))
                .foregroundStyle(MonMonTheme.savings)
                .accessibilityHidden(true)

            currencyTextField(text: text)
                .textFieldStyle(.plain)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
        .padding(16)
        .background(
            MonMonTheme.field,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    @ViewBuilder
    private func currencyTextField(text: Binding<String>) -> some View {
        VNDTextField(text: text)
    }

    private var difference: Decimal? {
        guard let principal = VNDCurrency.parse(draft.principalText),
            let received = VNDCurrency.parse(draft.amountReceivedText)
        else {
            return nil
        }

        return received - principal
    }

    private var principalErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidPrincipal:
            "Enter a valid principal amount."
        case .nonPositivePrincipal:
            "Principal withdrawn must be greater than zero."
        case .exceedsRemainingPrincipal:
            "That is more than the principal still deposited."
        default:
            nil
        }
    }

    private var receivedErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidAmountReceived:
            "Enter the amount the bank actually paid."
        case .negativeAmountReceived:
            "Amount received cannot be negative."
        default:
            nil
        }
    }

    private var dateErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .beforeOpeningDate:
            "Withdrawal date cannot be before the book was opened."
        case .futureDate:
            "Withdrawal date cannot be in the future."
        default:
            nil
        }
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

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }
}
