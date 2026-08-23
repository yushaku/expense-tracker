import SwiftUI

struct FundEditorForm: View {
    @Binding var draft: FundDraft

    let accounts: [CashAccount]
    let isEditing: Bool
    let validationError: FundFormError?
    let saveErrorMessage: String?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    detailsCard
                    positionCard
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.funds, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("What you hold, what it is worth")
                    .font(.title3.weight(.semibold))

                Text("Enter the latest NAV by hand; nothing is fetched online.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Holding", systemImage: "briefcase.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Name")

                    TextField("VinaCapital VESAF", text: $draft.name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("fund-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage, id: "fund-name-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Symbol")

                    TextField("VESAF", text: $draft.symbol)
                        .textFieldStyle(.plain)
                        .textCase(.uppercase)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("fund-symbol")

                    if let symbolErrorMessage {
                        validationMessage(symbolErrorMessage, id: "fund-symbol-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Type")

                    Picker("Type", selection: $draft.kind) {
                        ForEach(FundHoldingKind.allCases, id: \.rawValue) {
                            Text($0.displayName)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("fund-kind")
                }
            }
        }
    }

    private var positionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Position", systemImage: "chart.bar.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Units")

                    unitsTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .padding(16)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    if let unitsErrorMessage {
                        validationMessage(unitsErrorMessage, id: "fund-units-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Average cost per unit")

                    HStack(spacing: 12) {
                        Text("₫")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MonMonTheme.funds)

                        averageCostTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Average cost per unit")
                    }
                    .padding(14)
                    .background(
                        MonMonTheme.field,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                    if let averageCostErrorMessage {
                        validationMessage(
                            averageCostErrorMessage,
                            id: "fund-average-cost-error"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Current NAV per unit")

                    HStack(spacing: 12) {
                        Text("₫")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MonMonTheme.funds)

                        navTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Current NAV per unit")
                    }
                    .padding(14)
                    .background(
                        MonMonTheme.field,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                    if let navErrorMessage {
                        validationMessage(navErrorMessage, id: "fund-nav-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("NAV as of")

                    DateField(
                        selection: $draft.navAsOf,
                        accessibilityIdentifier: "fund-nav-date"
                    )
                }
            }
        }
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
                .accessibilityIdentifier("fund-source")

                if let sourceErrorMessage {
                    validationMessage(sourceErrorMessage, id: "fund-source-error")
                }

                Text(fundingExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete holding", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-fund")
    }

    @ViewBuilder
    private var unitsTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.unitsText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("fund-units")
        #else
            TextField("0", text: $draft.unitsText)
                .accessibilityIdentifier("fund-units")
        #endif
    }

    @ViewBuilder
    private var averageCostTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.averageCostText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("fund-average-cost")
        #else
            TextField("0", text: $draft.averageCostText)
                .accessibilityIdentifier("fund-average-cost")
        #endif
    }

    @ViewBuilder
    private var navTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.navText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("fund-nav")
        #else
            TextField("0", text: $draft.navText)
                .accessibilityIdentifier("fund-nav")
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
        validationMessage(message, id: "save-fund-error")
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

    private var fundingExplanation: String {
        if draft.sourceAccountID == nil {
            "Not linked: this holding adds to your total on its own."
        } else {
            "Linked: the cost basis leaves that account's available balance."
        }
    }

    private var nameErrorMessage: String? {
        guard validationError == .emptyName else { return nil }
        return "Enter a name for this holding."
    }

    private var symbolErrorMessage: String? {
        guard validationError == .emptySymbol else { return nil }
        return "Enter the fund or ETF symbol."
    }

    private var unitsErrorMessage: String? {
        switch validationError {
        case .invalidUnits:
            "Enter a valid number of units."
        case .nonPositiveUnits:
            "Units must be greater than zero."
        default:
            nil
        }
    }

    private var averageCostErrorMessage: String? {
        switch validationError {
        case .invalidAverageCost:
            "Enter a valid average cost per unit."
        case .nonPositiveAverageCost:
            "Average cost must be greater than zero."
        default:
            nil
        }
    }

    private var navErrorMessage: String? {
        switch validationError {
        case .invalidNAV:
            "Enter a valid NAV per unit."
        case .nonPositiveNAV:
            "NAV must be greater than zero."
        default:
            nil
        }
    }

    private var sourceErrorMessage: String? {
        guard validationError == .insufficientSourceBalance else { return nil }
        return "That account does not have enough available balance."
    }
}

#if DEBUG
    private struct FundEditorFormPreview: View {
        @State var draft: FundDraft
        var isEditing = false
        var validationError: FundFormError?
        var saveErrorMessage: String?

        var body: some View {
            NavigationStack {
                FundEditorForm(
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
                    validationError: validationError,
                    saveErrorMessage: saveErrorMessage,
                    onDelete: {}
                )
                .navigationTitle(isEditing ? "Edit holding" : "Add holding")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    #Preview("Fund form · empty") {
        FundEditorFormPreview(
            draft: FundDraft(navAsOf: Date(timeIntervalSince1970: 1_700_000_000))
        )
    }

    #Preview("Fund form · editing") {
        FundEditorFormPreview(
            draft: FundDraft(
                name: "VinaCapital VESAF",
                symbol: "VESAF",
                kind: .fund,
                unitsText: "1234,5678",
                averageCostText: "24.500",
                navText: "27.431",
                navAsOf: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            isEditing: true
        )
    }

    #Preview("Fund form · errors") {
        FundEditorFormPreview(
            draft: FundDraft(
                name: "Diamond ETF",
                symbol: "FUEVFVND",
                kind: .etf,
                unitsText: "100000",
                averageCostText: "32.100",
                navText: "29.850",
                navAsOf: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            validationError: .insufficientSourceBalance,
            saveErrorMessage: "Couldn’t save this holding. Try again."
        )
    }
#endif
