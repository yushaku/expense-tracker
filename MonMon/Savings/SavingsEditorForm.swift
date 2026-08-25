import SwiftUI

struct SavingsEditorForm: View {
    @Binding var draft: SavingsDraft

    let accounts: [CashAccount]
    let isEditing: Bool
    let termsLocked: Bool
    let validationError: SavingsFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    if termsLocked {
                        lockedTermsBanner
                    }
                    detailsCard
                    termsCard
                    fundingCard

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
            Image(systemName: "building.columns.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.savings, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Lock money in, watch it grow")
                    .font(.title3.weight(.semibold))

                Text("Projected interest assumes the book stays until maturity.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Savings book", systemImage: "text.book.closed.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Name")

                    TextField("Techcombank 6 months", text: $draft.name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("savings-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage, id: "savings-name-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Opened on")

                    DateField(
                        selection: $draft.openedAt,
                        accessibilityIdentifier: "savings-opened-at"
                    )
                    .disabled(termsLocked)
                }
            }
        }
    }

    private var termsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Deposit terms", systemImage: "banknote.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Principal")

                    HStack(spacing: 12) {
                        Text("₫")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MonMonTheme.savings)

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
                        validationMessage(
                            principalErrorMessage,
                            id: "savings-principal-error"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Annual rate")

                    HStack(spacing: 12) {
                        rateTextField
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(
                                MonMonTheme.field,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .accessibilityIdentifier("savings-rate")

                        Text("%/year")
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    if let rateErrorMessage {
                        validationMessage(rateErrorMessage, id: "savings-rate-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Term")

                    HStack(spacing: 12) {
                        termTextField
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(
                                MonMonTheme.field,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .accessibilityIdentifier("savings-term")

                        Text("months")
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    if let termErrorMessage {
                        validationMessage(termErrorMessage, id: "savings-term-error")
                    }
                }
            }
        }
        .disabled(termsLocked)
    }

    private var fundingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Funding source", systemImage: "arrow.left.arrow.right")

                Picker("Funding source", selection: $draft.sourceAccountID) {
                    Text("Not linked")
                        .tag(UUID?.none)

                    ForEach(accounts) { account in
                        Text(account.name)
                            .tag(UUID?.some(account.id))
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("savings-source")

                if let sourceErrorMessage {
                    validationMessage(sourceErrorMessage, id: "savings-source-error")
                }

                Text(fundingExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .disabled(termsLocked)
    }

    private var lockedTermsBanner: some View {
        Label(
            "Only the name can be changed after a withdrawal has been recorded.",
            systemImage: "lock.fill"
        )
        .font(.subheadline)
        .foregroundStyle(MonMonTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MonMonTheme.savings.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("savings-terms-locked")
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete savings book", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-savings")
    }

    @ViewBuilder
    private var principalTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.principalText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("savings-principal")
        #else
            TextField("0", text: $draft.principalText)
                .accessibilityIdentifier("savings-principal")
        #endif
    }

    @ViewBuilder
    private var rateTextField: some View {
        #if os(iOS)
            TextField("5,6", text: $draft.rateText)
                .keyboardType(.decimalPad)
        #else
            TextField("5,6", text: $draft.rateText)
        #endif
    }

    @ViewBuilder
    private var termTextField: some View {
        #if os(iOS)
            TextField("6", text: $draft.termMonthsText)
                .keyboardType(.numberPad)
        #else
            TextField("6", text: $draft.termMonthsText)
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
        validationMessage(message, id: "save-savings-error")
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

    private var fundingExplanation: LocalizedStringKey {
        if draft.sourceAccountID == nil {
            "Not linked: this deposit adds to your total on its own."
        } else {
            "Linked: the principal leaves that account's available balance."
        }
    }

    private var nameErrorMessage: LocalizedStringKey? {
        guard validationError == .emptyName else { return nil }
        return "Enter a name for this savings book."
    }

    private var principalErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidPrincipal:
            "Enter a valid principal."
        case .nonPositivePrincipal:
            "Principal must be greater than zero."
        default:
            nil
        }
    }

    private var rateErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidRate:
            "Enter a valid annual rate."
        case .rateOutOfRange:
            "Rate must be between 0 and 100."
        default:
            nil
        }
    }

    private var termErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidTerm:
            "Enter the term in whole months."
        case .termOutOfRange:
            "Term must be between 1 and 120 months."
        default:
            nil
        }
    }

    private var sourceErrorMessage: LocalizedStringKey? {
        guard validationError == .insufficientSourceBalance else { return nil }
        return "That account does not have enough available balance."
    }
}

#if DEBUG
    private struct SavingsEditorFormPreview: View {
        @State var draft: SavingsDraft
        var isEditing = false
        var validationError: SavingsFormError?
        var saveErrorMessage: LocalizedStringKey?

        var body: some View {
            NavigationStack {
                SavingsEditorForm(
                    draft: $draft,
                    accounts: [
                        .preview(name: "Wallet", kind: .cash, openingBalance: 1_250_000),
                        .preview(
                            name: "Techcombank",
                            kind: .bank,
                            openingBalance: 148_900_000
                        ),
                    ],
                    isEditing: isEditing,
                    termsLocked: false,
                    validationError: validationError,
                    saveErrorMessage: saveErrorMessage,
                    onDelete: {}
                )
                .navigationTitle(isEditing ? "Edit savings book" : "Add savings book")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    #Preview("Savings form · empty") {
        SavingsEditorFormPreview(
            draft: SavingsDraft(openedAt: Date(timeIntervalSince1970: 1_700_000_000))
        )
    }

    #Preview("Savings form · editing") {
        SavingsEditorFormPreview(
            draft: SavingsDraft(
                name: "Techcombank 6 months",
                principalText: "100.000.000",
                rateText: "5,6",
                termMonthsText: "6",
                openedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            isEditing: true
        )
    }

    #Preview("Savings form · errors") {
        SavingsEditorFormPreview(
            draft: SavingsDraft(
                name: "",
                principalText: "999.000.000",
                rateText: "5,6",
                termMonthsText: "6",
                openedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            validationError: .insufficientSourceBalance,
            saveErrorMessage: "Couldn’t save this savings book. Try again."
        )
    }
#endif
