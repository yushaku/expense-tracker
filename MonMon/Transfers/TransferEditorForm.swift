import SwiftUI

struct TransferEditorForm: View {
    @Binding var draft: TransferDraft

    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: TransferFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onSwap: () -> Void
    let onDelete: () -> Void
    var availableSourceBalance: Decimal? = nil

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    routeCard
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
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var amountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Transfer amount")
                HStack(spacing: 12) {
                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityHidden(true)

                    amountTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel("Amount")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let availableSourceBalance {
                    LabeledContent("Available to transfer") {
                        Text(VNDCurrency.format(availableSourceBalance))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }

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
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Transfer between accounts", systemImage: "arrow.left.arrow.right")
                if accounts.count < 2 {
                    Label(
                        "Transfers need two accounts. Add another on the Wealth tab first.",
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    accountPicker(
                        title: "From", selection: $draft.sourceAccountID,
                        otherID: draft.destinationAccountID, symbol: "arrow.up.right",
                        identifier: "transfer-source-account"
                    )
                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .accessibilityHidden(true)
                        Spacer()
                        Button(action: onSwap) {
                            Label("Swap", systemImage: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .labelStyle(.titleAndIcon)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MonMonTheme.accent)
                        .background(MonMonTheme.accent.opacity(0.12), in: .capsule)
                        .disabled(
                            draft.sourceAccountID == nil && draft.destinationAccountID == nil
                        )
                        .accessibilityIdentifier("swap-transfer-accounts")
                    }
                    .padding(.leading, 14)
                    accountPicker(
                        title: "To", selection: $draft.destinationAccountID,
                        otherID: draft.sourceAccountID, symbol: "arrow.down.left",
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
        title: LocalizedStringKey,
        selection: Binding<UUID?>,
        otherID: UUID?,
        symbol: String,
        identifier: String
    ) -> some View {
        let selected = accounts.first { $0.id == selection.wrappedValue }
        return Menu {
            Picker(title, selection: selection) {
                Text("Choose").tag(UUID?.none)
                ForEach(accounts) { account in
                    Label(account.name, systemImage: account.kind.iconName)
                        .tag(UUID?.some(account.id))
                        .disabled(account.id == otherID)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected?.kind.iconName ?? symbol)
                    .font(.title3)
                    .foregroundStyle(selected?.tint ?? MonMonTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                    if let selected {
                        Text(selected.name)
                            .font(.headline)
                            .foregroundStyle(MonMonTheme.textPrimary)
                    } else {
                        Text("Choose account")
                            .font(.headline)
                            .foregroundStyle(MonMonTheme.textPrimary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(MonMonTheme.field, in: .rect(cornerRadius: 14))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
        VNDTextField(text: $draft.amountText)
            .accessibilityIdentifier("transfer-amount")
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

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var amountErrorMessage: LocalizedStringKey? {
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

    private var routeErrorMessage: LocalizedStringKey? {
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
