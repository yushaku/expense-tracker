import SwiftUI

struct TransferEditorForm: View {
    @Binding var draft: TransferDraft

    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: TransferFormError?
    let saveErrorMessage: String?
    let onSwap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    amountCard
                    routeCard
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
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Fix what you moved" : "Move money you already have")
                    .font(.title3.weight(.semibold))

                Text("One account falls by this amount and the other rises by it.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var amountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
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
                    validationMessage(amountErrorMessage, id: "transfer-amount-error")
                }

                Text("VND · Your total assets do not change; only where the money sits does.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var routeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    sectionHeader("Route", systemImage: "arrow.left.arrow.right")

                    Spacer()

                    Button("Swap", systemImage: "arrow.up.arrow.down", action: onSwap)
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier("swap-transfer-accounts")
                }

                if accounts.count < 2 {
                    Text("Transfers need two accounts. Add another on the Home tab first.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    accountPicker(
                        title: "From",
                        selection: $draft.sourceAccountID,
                        identifier: "transfer-source-account"
                    )

                    accountPicker(
                        title: "To",
                        selection: $draft.destinationAccountID,
                        identifier: "transfer-destination-account"
                    )
                }

                if let routeErrorMessage {
                    validationMessage(routeErrorMessage, id: "transfer-route-error")
                }
            }
        }
    }

    private func accountPicker(
        title: String,
        selection: Binding<UUID?>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(title)

            Picker(title, selection: selection) {
                Text("Choose")
                    .tag(UUID?.none)

                ForEach(accounts) { account in
                    Text(account.name)
                        .tag(UUID?.some(account.id))
                }
            }
            .labelsHidden()
            .accessibilityIdentifier(identifier)
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
                        accessibilityIdentifier: "transfer-date"
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
                        .accessibilityIdentifier("transfer-note")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete transfer", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-transfer")
    }

    @ViewBuilder
    private var amountTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.amountText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("transfer-amount")
        #else
            TextField("0", text: $draft.amountText)
                .accessibilityIdentifier("transfer-amount")
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
        validationMessage(message, id: "save-transfer-error")
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
        case .insufficientSourceBalance:
            "That is more than the account you picked can hand over."
        default:
            nil
        }
    }

    private var routeErrorMessage: String? {
        switch validationError {
        case .missingSourceAccount:
            "Pick the account the money left."
        case .missingDestinationAccount:
            "Pick the account the money reached."
        case .sameAccount:
            "Pick two different accounts."
        default:
            nil
        }
    }
}
