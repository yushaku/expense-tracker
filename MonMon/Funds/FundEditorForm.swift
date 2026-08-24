import SwiftUI

struct FundEditorForm: View {
    @Binding var draft: FundDraft

    let accounts: [CashAccount]
    /// The catalogue to pick from. A position is held in something that already
    /// exists, so the form selects rather than retypes.
    let instruments: [FundInstrument]
    let isEditing: Bool
    let validationError: FundFormError?
    let saveErrorMessage: String?
    let onAddInstrument: () -> Void
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

                Text("Pick what you hold, then say how much of it you own.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Instrument", systemImage: "briefcase.fill")

                if instruments.isEmpty {
                    Text("No fund or ETF in the catalogue yet. Add one to hold it.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    Picker("Instrument", selection: $draft.instrumentID) {
                        Text("Choose")
                            .tag(UUID?.none)

                        ForEach(instruments) { instrument in
                            Text("\(instrument.symbol) · \(instrument.name)")
                                .tag(UUID?.some(instrument.id))
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("holding-instrument")
                }

                Button("Add instrument", systemImage: "plus.circle", action: onAddInstrument)
                    .font(.subheadline.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(MonMonTheme.accent)
                    .accessibilityIdentifier("add-instrument")

                if let instrumentErrorMessage {
                    validationMessage(instrumentErrorMessage, id: "holding-instrument-error")
                }

                if let selected {
                    Text(instrumentExplanation(selected))
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    private var selected: FundInstrument? {
        guard let id = draft.instrumentID else { return nil }
        return instruments.first { $0.id == id }
    }

    /// The price is stated here but not editable: it belongs to the instrument,
    /// and editing it from inside one position is exactly how two positions in
    /// one ticker used to end up disagreeing.
    private func instrumentExplanation(_ instrument: FundInstrument) -> String {
        let price = VNDCurrency.formatUnitPrice(instrument.currentPricePerUnit)
        let day = instrument.priceAsOf.formatted(date: .abbreviated, time: .omitted)
        return "\(instrument.kind.displayName) · \(instrument.priceLabel) \(price) as of \(day). "
            + "Edit the price under Instruments."
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
                    fieldLabel("Bought on")

                    DateField(
                        selection: $draft.purchasedAt,
                        accessibilityIdentifier: "fund-purchased-at"
                    )

                    Text(
                        "Today by default. Move it back to record a purchase made earlier."
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
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

    private var instrumentErrorMessage: String? {
        guard validationError == .missingInstrument else { return nil }
        return "Pick the fund or ETF this position is held in."
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

        private let instruments: [FundInstrument] = [
            .preview(
                name: "VinaCapital VESAF",
                symbol: "VESAF",
                kind: .fund,
                currentPricePerUnit: Decimal(string: "27431.28") ?? 0,
                source: .fmarket
            ),
            .preview(
                name: "Diamond ETF",
                symbol: "FUEVFVND",
                kind: .etf,
                currentPricePerUnit: 29_850,
                source: .vndirect
            ),
        ]

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
                    instruments: instruments,
                    isEditing: isEditing,
                    validationError: validationError,
                    saveErrorMessage: saveErrorMessage,
                    onAddInstrument: {},
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
        FundEditorFormPreview(draft: FundDraft())
    }

    #Preview("Fund form · editing") {
        FundEditorFormPreview(
            draft: FundDraft(
                unitsText: "1234,5678",
                averageCostText: "24.500"
            ),
            isEditing: true
        )
    }

    #Preview("Fund form · errors") {
        FundEditorFormPreview(
            draft: FundDraft(
                unitsText: "100000",
                averageCostText: "32.100"
            ),
            validationError: .insufficientSourceBalance,
            saveErrorMessage: "Couldn\u{2019}t save this holding. Try again."
        )
    }
#endif
