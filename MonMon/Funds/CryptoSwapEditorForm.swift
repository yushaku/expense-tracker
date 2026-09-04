import SwiftUI

/// The form for exchanging one coin for another. Presentation only: it neither
/// fetches a rate nor writes a record, the way every other editor form here
/// leaves both to its view.
struct CryptoSwapEditorForm: View {
    @Environment(\.locale) private var locale

    @Binding var draft: CryptoSwapDraft

    /// The coin being given up. Fixed by the lot the sheet was opened on.
    let givenInstrument: FundInstrument?
    /// What is still held in that lot, so the form can say what is left.
    let remainingUnits: Decimal
    /// The coins that can be received. Excludes the one being given, because a
    /// swap into the same coin is not a trade.
    let receivableInstruments: [FundInstrument]
    /// The coin chosen to receive, when one has been.
    var receivedInstrument: FundInstrument?
    /// How much of it today's prices say the given units would buy. A
    /// suggestion under the field, never in it.
    var marketImpliedUnitsReceived: Decimal?
    var onUseImpliedUnitsReceived: () -> Void = {}
    let isEditing: Bool
    let validationError: CryptoSwapFormError?
    let saveErrorMessage: LocalizedStringKey?
    var rateStatusMessage: String?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    givenCard
                    receivedCard
                    valueCard
                    outcomeCard

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
                .background(MonMonTheme.crypto, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("One coin for another")
                    .font(.title3.weight(.semibold))

                Text(
                    "No money leaves or arrives. What you gave settles its gain, and what you got starts at what it cost."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var givenCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("You gave", systemImage: "arrow.up.right")

                if let givenInstrument {
                    Text(givenInstrument.symbol)
                        .font(.headline)
                        .foregroundStyle(MonMonTheme.textPrimary)
                }

                quantityField(
                    text: $draft.unitsGivenText,
                    identifier: "swap-units-given",
                    label: "Quantity given"
                )

                if let message = quantityGivenErrorMessage {
                    validationMessage(message, id: "swap-units-given-error")
                }

                Text("\(UnitQuantity.format(remainingUnits)) held in this lot.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var receivedCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("You got", systemImage: "arrow.down.left")

                Picker("Coin received", selection: $draft.receivedInstrumentID) {
                    Text("Choose").tag(UUID?.none)
                    ForEach(receivableInstruments) { instrument in
                        Text(instrument.symbol).tag(UUID?.some(instrument.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("swap-received-instrument")

                if let message = receivedInstrumentErrorMessage {
                    validationMessage(message, id: "swap-received-instrument-error")
                }

                quantityField(
                    text: $draft.unitsReceivedText,
                    identifier: "swap-units-received",
                    label: "Quantity received"
                )

                if let message = quantityReceivedErrorMessage {
                    validationMessage(message, id: "swap-units-received-error")
                }

                // Not filled in for you: what came back is a fact off an
                // exchange screen, and a guess left in that box would quietly
                // become the position. Offered to tap instead.
                if let impliedUnitsDescription {
                    Button(action: onUseImpliedUnitsReceived) {
                        Text("At today's prices that is about \(impliedUnitsDescription). Use it")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.accent)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("swap-use-implied-units")
                }
            }
        }
    }

    /// The suggested quantity with its ticker, or `nil` when no coin is chosen
    /// or nothing has a price to work from.
    private var impliedUnitsDescription: String? {
        guard let marketImpliedUnitsReceived, let receivedInstrument else {
            return nil
        }
        return "\(UnitQuantity.format(marketImpliedUnitsReceived)) \(receivedInstrument.symbol)"
    }

    /// One field, and the reason it is one field rather than two.
    private var valueCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("What the trade was worth", systemImage: "tag.fill")

                SegmentedTabs(
                    label: "Value currency",
                    selection: $draft.valueCurrency,
                    options: PriceEntryCurrency.allCases,
                    title: \.displayName
                )
                .accessibilityIdentifier("swap-value-currency")

                HStack(spacing: 12) {
                    Text(draft.valueCurrency.symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MonMonTheme.crypto)
                        .accessibilityHidden(true)

                    valueTextField
                        .textFieldStyle(.plain)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Value of this swap")
                }
                .padding(14)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let message = valueErrorMessage {
                    validationMessage(message, id: "swap-value-error")
                }

                if draft.valueCurrency == .usd {
                    exchangeRateField
                }

                Text(valueExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Swapped on")
                        .font(.subheadline.weight(.medium))

                    DateField(
                        selection: $draft.swappedAt,
                        accessibilityIdentifier: "swap-date"
                    )
                }
            }
        }
    }

    private var exchangeRateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rate used (₫ per $)")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 12) {
                Text("₫")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MonMonTheme.crypto)
                    .accessibilityHidden(true)

                VNDTextField(text: $draft.exchangeRateText, keyboard: .decimal)
                    .textFieldStyle(.plain)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Rate used")
                    .accessibilityIdentifier("swap-exchange-rate")
            }
            .padding(14)
            .background(
                MonMonTheme.field,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            if let message = exchangeRateErrorMessage {
                validationMessage(message, id: "swap-exchange-rate-error")
            }

            if let rateStatusMessage {
                Text(rateStatusMessage)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else if isEditing {
                Text("Rate at the swap, \(TransactionPeriod.day(draft.swappedAt, in: locale)).")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            if let convertedValue {
                Text("Stored as \(convertedValue) ₫")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("swap-converted-value")
            }
        }
    }

    /// What the trade did to the coin given up, worked out live so the owner
    /// sees the settled gain before committing to it.
    @ViewBuilder
    private var outcomeCard: some View {
        if let valueInDong, let givenInstrument {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("What this settles", systemImage: "checkmark.seal.fill")

                    Text(
                        "\(givenInstrument.symbol) leaves the lot at \(VNDCurrency.format(valueInDong)), and that is what the new position cost."
                    )
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete this swap", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .background(
            MonMonTheme.danger.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
        }
        .accessibilityIdentifier("delete-swap")
    }

    // MARK: - Fields

    @ViewBuilder
    private func quantityField(
        text: Binding<String>,
        identifier: String,
        label: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 12) {
            #if os(iOS)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier(identifier)
            #else
                TextField("0", text: text)
                    .accessibilityIdentifier(identifier)
            #endif
        }
        .textFieldStyle(.plain)
        .monospacedDigit()
        .accessibilityLabel(label)
        .padding(14)
        .background(
            MonMonTheme.field,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    @ViewBuilder
    private var valueTextField: some View {
        if draft.valueCurrency == .usd {
            #if os(iOS)
                TextField("0", text: $draft.valueText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("swap-value")
            #else
                TextField("0", text: $draft.valueText)
                    .accessibilityIdentifier("swap-value")
            #endif
        } else {
            VNDTextField(text: $draft.valueText, keyboard: .decimal)
                .accessibilityIdentifier("swap-value")
        }
    }

    // MARK: - Derived copy

    /// What this field is for, in the owner's terms rather than the schema's.
    ///
    /// The question it answers first is "why am I being asked this at all",
    /// which the field's own name does not: the two quantities are facts off an
    /// exchange screen, and this is the đồng they get booked at.
    private var valueExplanation: LocalizedStringKey {
        guard let symbol = givenInstrument?.symbol else {
            return
                "This is what both sides are booked at: the gain the coin you gave settles, and what the coin you got cost."
        }
        return
            "Filled in from today's \(symbol) price. It is what both sides are booked at — the gain \(symbol) settles, and what the coin you got cost. Change it if the trade went through at a different price."
    }

    /// The trade's worth in đồng, whichever currency it was typed in.
    private var valueInDong: Decimal? {
        switch draft.valueCurrency {
        case .vnd:
            guard let value = VNDCurrency.parse(draft.valueText), value > 0 else {
                return nil
            }
            return value
        case .usd:
            guard let dollars = USDPrice.parse(draft.valueText),
                let rate = VNDCurrency.parse(draft.exchangeRateText)
            else {
                return nil
            }
            return USDPrice.inDong(dollars, rate: rate)
        }
    }

    private var convertedValue: String? {
        guard draft.valueCurrency == .usd, let valueInDong else {
            return nil
        }
        return VNDCurrency.formatUnitPrice(valueInDong)
    }

    private var quantityGivenErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidUnitsGiven:
            "Enter a valid quantity."
        case .nonPositiveUnitsGiven:
            "Enter a quantity greater than zero."
        case .exceedsRemainingUnits:
            "That is more than is still held here."
        default:
            nil
        }
    }

    private var receivedInstrumentErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .missingReceivedInstrument:
            "Choose the coin you got."
        case .sameInstrument:
            "Choose a different coin from the one you gave."
        default:
            nil
        }
    }

    private var quantityReceivedErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidUnitsReceived:
            "Enter a valid quantity."
        case .nonPositiveUnitsReceived:
            "Enter a quantity greater than zero."
        default:
            nil
        }
    }

    private var valueErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidValue:
            draft.valueCurrency == .usd
                ? "Enter what the trade was worth, in dollars."
                : "Enter what the trade was worth, in đồng."
        case .nonPositiveValue:
            "The value must be greater than zero."
        default:
            nil
        }
    }

    private var exchangeRateErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidExchangeRate:
            "Enter the rate you used, in đồng per dollar."
        case .nonPositiveExchangeRate:
            "The rate must be greater than zero."
        default:
            nil
        }
    }

    // MARK: - Chrome

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

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier("swap-save-error")
    }
}
