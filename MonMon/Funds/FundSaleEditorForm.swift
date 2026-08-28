import SwiftUI

struct FundSaleEditorForm: View {
    @Environment(\.locale) private var locale

    @Binding var draft: FundSaleDraft

    let instrument: FundInstrument?
    /// The units still held, in the unit the owner types — chỉ for gold, units
    /// otherwise. Already has the edited sale's own units added back, so the
    /// caption never accuses the owner of overselling what they are re-saving.
    let remainingUnits: Decimal
    /// What one unit cost the owner. What the live readout measures against.
    let averageCostPerUnit: Decimal
    let accounts: [CashAccount]
    let isGold: Bool
    /// Whether this closes every open lot in the fund at once, rather than the
    /// single lot the card was opened from.
    let isClosingGroup: Bool
    let isEditing: Bool
    let validationError: FundSaleFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onSellEverything: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction

                    // Closing the whole position has no quantity to choose: it
                    // sells every open lot, and asking how much would invite a
                    // number that contradicts the button that opened this.
                    if !isClosingGroup {
                        quantityCard
                    }

                    priceCard
                    outcomeCard
                    accountCard
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
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.funds)
                .frame(width: 46, height: 46)
                .background(
                    MonMonTheme.funds.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var title: LocalizedStringKey {
        if isEditing {
            return "Fix what you recorded"
        }

        return isClosingGroup ? "Close the whole position" : "Sell out of this position"
    }

    private var subtitle: LocalizedStringKey {
        let held = quantityDescription(remainingUnits)

        if isClosingGroup {
            return "\(held) still held across every open position in \(symbol)."
        }

        return "\(held) still held in this position."
    }

    private var symbol: String {
        instrument?.symbol ?? "??"
    }

    private var quantityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionHeader(
                        isGold ? "Weight to sell" : "Units to sell",
                        systemImage: "scalemass.fill"
                    )

                    Spacer()

                    if remainingUnits > 0 {
                        Button("Sell it all", systemImage: "checkmark.circle.fill") {
                            onSellEverything()
                        }
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier("fund-sale-sell-everything")
                    }
                }

                HStack(spacing: 12) {
                    unitsTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .accessibilityLabel(isGold ? "Weight" : "Units")

                    Text(isGold ? "chỉ" : "units")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let quantityErrorMessage {
                    validationMessage(quantityErrorMessage, id: "fund-sale-units-error")
                }

                Text(remainderCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    /// Live, so the owner can watch a sale land exactly on closed before saving
    /// it.
    private var remainderCaption: LocalizedStringKey {
        guard let units = UnitQuantity.parse(draft.unitsText), units > 0 else {
            return isClosingGroup
                ? "Every open position in this fund is sold at the price below."
                : "What is left keeps the same average cost it always had."
        }

        let remainder = remainingUnits - units

        if remainder == 0 {
            return "Nothing left — this closes the position."
        }

        if remainder < 0 {
            return "That is more than is still held."
        }

        return "\(quantityDescription(remainder)) still held after this sale."
    }

    private var priceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(priceTitle, systemImage: "tag.fill")

                HStack(spacing: 12) {
                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityHidden(true)

                    priceTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Sale price per unit")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let priceErrorMessage {
                    validationMessage(priceErrorMessage, id: "fund-sale-price-error")
                }

                Text(priceCaption)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var priceTitle: LocalizedStringKey {
        isGold ? "Price per lượng" : "Price per unit"
    }

    /// Gold is quoted from the shop's side, so the figure the app already holds
    /// is what the shop pays — which is exactly what the owner receives. Saying
    /// so stops the sell price being read as the number on the shop's window.
    private var priceCaption: LocalizedStringKey {
        isGold
            ? "Filled in from the shop's buy price — what the shop pays you, not what it charges."
            : "You paid \(VNDCurrency.formatUnitPrice(averageCostPerUnit)) per unit on average."
    }

    /// What the sale comes to, worked out live so the owner sees the profit
    /// before committing to it rather than after.
    private var outcomeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("What this makes", systemImage: "chart.line.uptrend.xyaxis")

                if let outcome {
                    FundMetricGrid(
                        metrics: [
                            FundMetric(
                                titleKey: "PROCEEDS",
                                value: VNDCurrency.format(outcome.proceeds)
                            ),
                            FundMetric(
                                titleKey: "COST OF WHAT GOES",
                                value: VNDCurrency.format(outcome.cost)
                            ),
                        ]
                    )

                    FundProfitLossRow(
                        kind: .realized,
                        profitLoss: outcome.profitLoss,
                        returnPercent: outcome.returnPercent
                    )
                } else {
                    Text("Fill in a quantity and a price to see what this sale makes.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Text("Net worth does not move: the position turns into cash worth the same.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private struct Outcome {
        var proceeds: Decimal
        var cost: Decimal
        var profitLoss: Decimal
        var returnPercent: Decimal
    }

    /// What the sale comes to. `nil` until both figures are there, so the card
    /// says what it needs rather than showing a confident zero.
    private var outcome: Outcome? {
        guard let typed = UnitQuantity.parse(draft.unitsText), typed > 0,
            let price = VNDCurrency.parse(draft.pricePerUnitText), price > 0
        else {
            return nil
        }

        // Gold is typed in chỉ but priced and stored per lượng — the same
        // split `FundEditorForm` already lives with — so the quantity has to
        // come back to lượng before it meets the price.
        let units = isGold ? typed / GoldWeight.chiPerLuong : typed

        let proceeds = FundValuation.marketValue(units: units, pricePerUnit: price)
        let cost = FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)

        return Outcome(
            proceeds: proceeds,
            cost: cost,
            profitLoss: proceeds - cost,
            returnPercent: cost > 0 ? (proceeds - cost) / cost * 100 : .zero
        )
    }

    private var accountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Where the money goes", systemImage: "arrow.down.circle.fill")

                if accounts.isEmpty {
                    Text("A sale needs an account to pay into. Add one on the Home tab first.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Account")

                        Picker("Account", selection: $draft.proceedsAccountID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(accounts) { account in
                                Text(account.name)
                                    .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("fund-sale-account")
                    }
                }

                if let accountErrorMessage {
                    validationMessage(accountErrorMessage, id: "fund-sale-account-error")
                }

                Text("This account rises by the proceeds.")
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
                    fieldLabel("Date sold")

                    DateField(
                        selection: $draft.soldAt,
                        accessibilityIdentifier: "fund-sale-date"
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
                        .accessibilityIdentifier("fund-sale-note")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete this sale", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-fund-sale")
    }

    private func quantityDescription(_ quantity: Decimal) -> String {
        isGold
            ? "\(UnitQuantity.format(quantity)) \(AppText.string("chỉ", in: locale))"
            : "\(UnitQuantity.format(quantity)) \(AppText.string("units", in: locale))"
    }

    @ViewBuilder
    private var unitsTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.unitsText)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("fund-sale-units")
        #else
            TextField("0", text: $draft.unitsText)
                .accessibilityIdentifier("fund-sale-units")
        #endif
    }

    @ViewBuilder
    private var priceTextField: some View {
        VNDTextField(text: $draft.pricePerUnitText)
            .accessibilityIdentifier("fund-sale-price")
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
        validationMessage(message, id: "save-fund-sale-error")
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

    private var quantityErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidUnits:
            isGold ? "Enter a valid weight." : "Enter a valid number of units."
        case .nonPositiveUnits:
            "Enter a quantity greater than zero."
        case .exceedsRemainingUnits:
            "That is more than is still held here."
        default:
            nil
        }
    }

    private var priceErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidPrice:
            "Enter a valid price."
        case .nonPositivePrice:
            "Enter a price greater than zero."
        default:
            nil
        }
    }

    private var accountErrorMessage: LocalizedStringKey? {
        validationError == .missingAccount ? "Pick the account the money lands in." : nil
    }
}
