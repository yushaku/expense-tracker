import SwiftUI

struct FundInstrumentEditorForm: View {
    @Binding var draft: FundInstrumentDraft

    let kinds: [FundInstrumentKind]
    let isEditing: Bool
    /// How many positions are held in this instrument. Above zero, deleting is
    /// refused and the reason names the count.
    let heldCount: Int
    let validationError: FundInstrumentFormError?
    let saveErrorMessage: String?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    identityCard
                    priceCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteSection
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
                Text(isEditing ? "What this is worth" : "Something you can hold")
                    .font(.title3.weight(.semibold))

                Text("One ticker, one price. Every position in it is valued from here.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var identityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Identity", systemImage: "tag.fill")

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
                    fieldLabel("Type")

                    if kinds.count == 1 {
                        Text(draft.kind.displayName)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                MonMonTheme.field,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .accessibilityIdentifier("fund-kind")
                    } else {
                        Picker("Type", selection: $draft.kind) {
                            ForEach(kinds, id: \.rawValue) {
                                Text($0.displayName)
                                    .tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("fund-kind")
                    }

                    Text(kindExplanation)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    private var priceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Price", systemImage: "banknote.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(draft.kind.priceLabel)

                    HStack(spacing: 12) {
                        priceTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(draft.kind.priceLabel)

                        Text("₫")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MonMonTheme.funds)
                    }
                    .padding(14)
                    .background(
                        MonMonTheme.field,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                    if let priceErrorMessage {
                        validationMessage(priceErrorMessage, id: "instrument-price-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Price as of")

                    DateField(
                        selection: $draft.priceAsOf,
                        accessibilityIdentifier: "instrument-price-date"
                    )

                    Text("The trading day this figure belongs to, not the day you typed it.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Toggle("Automatic quotes", isOn: $draft.autoQuoteEnabled)
                    .accessibilityIdentifier("auto-quote")

                Text(autoQuoteExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if heldCount > 0 {
            validationMessage(
                "\(heldCount) \(heldCount == 1 ? "position is" : "positions are") held in this. "
                    + "Delete them first.",
                id: "delete-instrument-blocked"
            )
        } else {
            Button(role: .destructive, action: onDelete) {
                Label("Delete instrument", systemImage: "trash.fill")
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
            .accessibilityIdentifier("delete-instrument")
        }
    }

    @ViewBuilder
    private var priceTextField: some View {
        #if os(iOS)
            TextField("0", text: priceTextBinding)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("instrument-price")
        #else
            TextField("0", text: priceTextBinding)
                .accessibilityIdentifier("instrument-price")
        #endif
    }

    private var priceTextBinding: Binding<String> {
        Binding(
            get: { draft.priceText },
            set: { draft.priceText = VNDCurrency.formatInput($0) }
        )
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
        validationMessage(message, id: "save-instrument-error")
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

    private var kindExplanation: String {
        switch draft.kind {
        case .fund:
            "An open-ended fund is priced by the NAV its manager publishes, a day behind."
        case .etf:
            "A listed ETF is priced by its close, which sits above or below its NAV."
        case .gold:
            "Gold is valued at the shop's buy price per lượng."
        }
    }

    private var autoQuoteExplanation: String {
        draft.autoQuoteEnabled
            ? "Refresh will fetch this ticker, and an out-of-date price is marked stale."
            : "Refresh skips this ticker and its price is never marked stale."
    }

    private var symbolErrorMessage: String? {
        switch validationError {
        case .emptySymbol:
            "Enter the fund or ETF symbol."
        case .duplicateSymbol:
            "That symbol is already in the catalogue."
        default:
            nil
        }
    }

    private var nameErrorMessage: String? {
        guard validationError == .emptyName else { return nil }
        return "Enter a name for this instrument."
    }

    private var priceErrorMessage: String? {
        switch validationError {
        case .invalidPrice:
            "Enter a valid price per unit."
        case .nonPositivePrice:
            "The price must be greater than zero."
        default:
            nil
        }
    }
}
