import SwiftUI

struct QuickExpensePresetRow: View {
    @Binding var draft: QuickExpensePresetDraft

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                fields
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                fields
            }
        }
    }

    private var title: some View {
        Text(draft.slot.title)
            .font(.subheadline.weight(.medium))
    }

    private var fields: some View {
        HStack(spacing: 10) {
            TextField("Emoji", text: $draft.symbol)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .accessibilityLabel(Text(draft.slot.emojiFieldLabel))
                .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-symbol")

            TextField("Amount", text: $draft.amountText)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(minWidth: 116)
                .onChange(of: draft.amountText) {
                    let formatted = VNDCurrency.formatInput(draft.amountText)
                    if formatted != draft.amountText {
                        draft.amountText = formatted
                    }
                }
                .accessibilityLabel(Text(draft.slot.amountFieldLabel))
                .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-amount")
        }
        .textFieldStyle(.roundedBorder)
    }
}

extension QuickExpenseSlot {
    var editorIndex: Int {
        switch self {
        case .coffee: 0
        case .lunch: 1
        case .fuel: 2
        case .groceries: 3
        case .parking: 4
        case .transit: 5
        case .medicine: 6
        case .entertainment: 7
        case .bills: 8
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .coffee: "Coffee"
        case .lunch: "Lunch"
        case .fuel: "Fuel"
        case .groceries: "Groceries"
        case .parking: "Parking"
        case .transit: "Transit"
        case .medicine: "Medicine"
        case .entertainment: "Entertainment"
        case .bills: "Bills"
        }
    }

    var emojiFieldLabel: LocalizedStringResource {
        switch self {
        case .coffee: "Coffee emoji"
        case .lunch: "Lunch emoji"
        case .fuel: "Fuel emoji"
        case .groceries: "Groceries emoji"
        case .parking: "Parking emoji"
        case .transit: "Transit emoji"
        case .medicine: "Medicine emoji"
        case .entertainment: "Entertainment emoji"
        case .bills: "Bills emoji"
        }
    }

    var amountFieldLabel: LocalizedStringResource {
        switch self {
        case .coffee: "Coffee amount"
        case .lunch: "Lunch amount"
        case .fuel: "Fuel amount"
        case .groceries: "Groceries amount"
        case .parking: "Parking amount"
        case .transit: "Transit amount"
        case .medicine: "Medicine amount"
        case .entertainment: "Entertainment amount"
        case .bills: "Bills amount"
        }
    }
}
