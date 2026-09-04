import SwiftUI

struct FundEditorForm: View {
    @Environment(\.locale) private var locale

    @Binding var draft: FundDraft

    let accounts: [CashAccount]
    /// The catalogue to pick from. A position is held in something that already
    /// exists, so the form selects rather than retypes.
    let instruments: [FundInstrument]
    /// The kinds this form is scoped to, as its editor was opened with. The
    /// copy and the units follow from it: gold is weighed in chỉ, a coin is
    /// counted to eight places, and a fund or ETF in whole-ish units.
    let kinds: [FundInstrumentKind]
    let isEditing: Bool
    let validationError: FundFormError?
    let saveErrorMessage: LocalizedStringKey?
    /// What the rate lookup has to say, when it has anything. The form neither
    /// fetches nor decides — it only shows what the editor found out.
    var rateStatusMessage: String?
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
            Image(systemName: introductionSymbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.funds, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(introductionTitle)
                    .font(.title3.weight(.semibold))

                Text(introductionDescription)
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
                    Text(emptyInstrumentText)
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

                Button(addInstrumentTitle, systemImage: "plus.circle", action: onAddInstrument)
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
        let day = TransactionPeriod.day(instrument.priceAsOf, in: locale)
        return AppText.string(
            """
            \(instrument.kind.displayName(in: locale)) · \
            \(instrument.priceLabel(in: locale)) \(price) as of \(day). \
            Edit the price under Instruments.
            """,
            in: locale
        )
    }

    private var positionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Position", systemImage: "chart.bar.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(instrumentPolicy.quantity.holdingFieldTitle)

                    HStack(spacing: 12) {
                        unitsTextField
                            .textFieldStyle(.plain)
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .monospacedDigit()

                        Text(instrumentPolicy.quantity.entryUnitLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .accessibilityHidden(true)
                    }
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
                    fieldLabel(averageCostLabel)

                    if offersDollarEntry {
                        SegmentedTabs(
                            label: "Cost currency",
                            selection: $draft.costCurrency,
                            options: PriceEntryCurrency.allCases,
                            title: \.displayName
                        )
                        .accessibilityIdentifier("fund-cost-currency")
                    }

                    HStack(spacing: 12) {
                        Text(draft.costCurrency.symbol)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MonMonTheme.funds)

                        averageCostTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(averageCostLabel)

                        Text(perPriceUnitLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .accessibilityHidden(true)
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

                    if !isEditing {
                        Text(
                            "Filled in from today's buy price. Change it to what you actually paid."
                        )
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .accessibilityIdentifier("fund-average-cost-hint")
                    }
                }

                if let costWorkingText {
                    Text(costWorkingText)
                        .font(.footnote)
                        .foregroundStyle(MonMonTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("fund-cost-working")
                }

                if draft.costCurrency == .usd {
                    exchangeRateField
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
        // Đồng gets the grouping field the rest of the app types money into.
        // Dollars get a plain decimal box: đồng grouping would put a separator
        // where a dollar's decimal point belongs.
        if draft.costCurrency == .usd {
            plainDecimalField(text: $draft.averageCostText, identifier: "fund-average-cost")
        } else {
            VNDTextField(text: $draft.averageCostText, keyboard: .decimal)
                .accessibilityIdentifier("fund-average-cost")
        }
    }

    /// The rate box, shown only while the cost is being typed in dollars.
    ///
    /// It carries a fetched starting value and stays editable, because the rate
    /// that matters is the one the owner's exchange gave them, not a published
    /// mid. What lands in the store is the đồng underneath, and it is spelled
    /// out here so nothing is converted out of sight.
    private var exchangeRateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Rate used (₫ per $)")

            HStack(spacing: 12) {
                Text("₫")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MonMonTheme.funds)

                VNDTextField(text: $draft.exchangeRateText, keyboard: .decimal)
                    .textFieldStyle(.plain)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Rate used")
                    .accessibilityIdentifier("fund-exchange-rate")
            }
            .padding(14)
            .background(
                MonMonTheme.field,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            if let exchangeRateErrorMessage {
                validationMessage(exchangeRateErrorMessage, id: "fund-exchange-rate-error")
            }

            if let rateStatusMessage {
                Text(rateStatusMessage)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else if let storedRateCaption {
                Text(storedRateCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("fund-stored-rate-caption")
            }

            if let convertedCost {
                Text("Stored as \(convertedCost) ₫")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("fund-converted-cost")
            }
        }
    }

    @ViewBuilder
    private func plainDecimalField(text: Binding<String>, identifier: String) -> some View {
        #if os(iOS)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(identifier)
        #else
            TextField("0", text: text)
                .accessibilityIdentifier(identifier)
        #endif
    }

    /// The đồng the typed dollars come to, so the owner sees the number that
    /// will actually be stored before storing it. Absent until both boxes hold
    /// something usable.
    private var convertedCost: String? {
        guard draft.costCurrency == .usd,
            let dollars = USDPrice.parse(draft.averageCostText),
            let rate = VNDCurrency.parse(draft.exchangeRateText),
            let dong = USDPrice.inDong(dollars, rate: rate)
        else {
            return nil
        }
        return VNDCurrency.formatUnitPrice(dong)
    }

    /// Says the rate in the box is the one this position was bought at, not a
    /// rate the app forgot to refresh.
    ///
    /// Only while editing, and only when nothing was fetched this time round —
    /// a fetched rate has `rateStatusMessage` to explain itself, and saying
    /// both would be two answers to one question.
    private var storedRateCaption: LocalizedStringKey? {
        guard isEditing, draft.costCurrency == .usd else {
            return nil
        }
        return "Rate at purchase, \(TransactionPeriod.day(draft.purchasedAt, in: locale))."
    }

    /// Dollars are offered where things are actually bought in them. Vietnamese
    /// funds, ETFs and gold are bought in đồng, so a currency switch on those
    /// forms would be a box to ignore rather than a feature.
    private var perPriceUnitLabel: String {
        "/ \(AppText.string(key: instrumentPolicy.priceUnitLabelKey, in: locale))"
    }

    /// The purchase spelled out: how much, at what, for how much altogether.
    ///
    /// Gold is the reason this exists. It is bought in chỉ and quoted per
    /// lượng, so two adjacent boxes hold numbers in different units and nothing
    /// on screen related them — "2" and "150.000.000" reads as a purchase ten
    /// times the size of the one being recorded. This line does the conversion
    /// where it can be seen, and ends on the figure that actually leaves the
    /// funding account.
    ///
    /// `nil` until both boxes hold something usable, so it never shows a
    /// confident zero.
    private var costWorkingText: String? {
        guard
            let storedUnits = instrumentPolicy.quantity.storedUnits(
                fromEntryText: draft.unitsText
            ), storedUnits > 0, let perUnit = averageCostPerUnitInDong, perUnit > 0
        else {
            return nil
        }

        let quantity = instrumentPolicy.quantity.summaryValue(storedUnits: storedUnits)
        let priceUnit = AppText.string(key: instrumentPolicy.priceUnitLabelKey, in: locale)
        let total = FundValuation.costBasis(units: storedUnits, averageCostPerUnit: perUnit)

        return "\(quantity) × \(VNDCurrency.formatUnitPrice(perUnit)) ₫/\(priceUnit)"
            + " = \(VNDCurrency.formatPlain(total)) ₫"
    }

    /// The typed cost in đồng, whichever currency it was typed in.
    private var averageCostPerUnitInDong: Decimal? {
        switch draft.costCurrency {
        case .vnd:
            return VNDCurrency.parse(draft.averageCostText)
        case .usd:
            guard let dollars = USDPrice.parse(draft.averageCostText),
                let rate = VNDCurrency.parse(draft.exchangeRateText)
            else {
                return nil
            }
            return USDPrice.inDong(dollars, rate: rate)
        }
    }

    private var offersDollarEntry: Bool { instrumentPolicy.allowsDollarPriceEntry }

    private var averageCostLabel: LocalizedStringKey {
        LocalizedStringKey(instrumentPolicy.editor.averageCostTitleKey)
    }

    private var exchangeRateErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidExchangeRate:
            "Enter the rate you paid, in đồng per dollar."
        case .nonPositiveExchangeRate:
            "The rate must be greater than zero."
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

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
    }

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
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

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var fundingExplanation: LocalizedStringKey {
        if draft.sourceAccountID == nil {
            "Not linked: this holding adds to your total on its own."
        } else {
            "Linked: the cost basis leaves that account's available balance."
        }
    }

    private var instrumentErrorMessage: LocalizedStringKey? {
        guard validationError == .missingInstrument else { return nil }
        return LocalizedStringKey(instrumentPolicy.editor.missingInstrumentMessageKey)
    }

    private var unitsErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidUnits:
            instrumentPolicy.quantity.invalidHoldingMessage
        case .nonPositiveUnits:
            instrumentPolicy.quantity.nonPositiveHoldingMessage
        default:
            nil
        }
    }

    private var averageCostErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidAverageCost:
            draft.costCurrency == .usd
                ? "Enter a valid average cost in dollars."
                : "Enter a valid average cost per unit."
        case .nonPositiveAverageCost:
            "Average cost must be greater than zero."
        default:
            nil
        }
    }

    private var sourceErrorMessage: LocalizedStringKey? {
        guard validationError == .insufficientSourceBalance else { return nil }
        return "That account does not have enough available balance."
    }

    private var emptyInstrumentText: String {
        instrumentPolicy.editor.emptyCatalogueMessageKey
    }

    private var addInstrumentTitle: String {
        instrumentPolicy.editor.addInstrumentTitleKey
    }

    private var introductionSymbol: String {
        instrumentPolicy.editor.introductionSymbol
    }

    private var introductionTitle: LocalizedStringKey {
        LocalizedStringKey(instrumentPolicy.editor.introductionTitleKey)
    }

    private var introductionDescription: LocalizedStringKey {
        LocalizedStringKey(instrumentPolicy.editor.introductionDescriptionKey)
    }

    private var instrumentPolicy: FundInstrumentPolicy {
        (kinds.first ?? .fund).policy
    }
}

#if DEBUG
    private struct FundEditorFormPreview: View {
        @State var draft: FundDraft
        var isEditing = false
        var validationError: FundFormError?
        var saveErrorMessage: LocalizedStringKey?

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
                        .preview(name: "Wallet", kind: .normal, openingBalance: 1_250_000),
                        .preview(
                            name: "Techcombank",
                            kind: .normal,
                            openingBalance: 148_900_000
                        ),
                    ],
                    instruments: instruments,
                    kinds: [.fund, .etf],
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
