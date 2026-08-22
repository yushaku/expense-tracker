import SwiftUI

struct AddAccountForm: View {
    @Binding var draft: AccountDraft

    let validationError: AccountFormError?
    let saveErrorMessage: String?

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
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Give your money a home")
                    .font(.title3.weight(.semibold))

                Text("Start with the balance available today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
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

                Text("VND · This becomes the current balance for this account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var balanceTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.openingBalanceText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("opening-balance")
        #else
            TextField("0", text: $draft.openingBalanceText)
                .accessibilityIdentifier("opening-balance")
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
            .foregroundStyle(.primary)
    }

    private func errorBanner(_ message: String) -> some View {
        validationMessage(message, id: "save-account-error")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
            }
    }

    private func validationMessage(_ message: String, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .accessibilityIdentifier(id)
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
}
