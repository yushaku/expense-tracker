import SwiftUI

struct QuickExpensePresetRow: View {
    @Binding var draft: QuickExpensePresetDraft
    let categories: [TransactionCategory]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                nameField
                    .frame(minWidth: 64, maxWidth: 84)
                verticalDivider
                amountField
                    .frame(minWidth: 96, maxWidth: .infinity)
                verticalDivider
                categoryField
                    .frame(minWidth: 108, maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    nameField
                    verticalDivider
                    amountField
                }
                horizontalDivider
                categoryField
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            MonMonTheme.field,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private var hasStaleSelection: Bool {
        guard let categoryID = draft.categoryID else {
            return false
        }
        return !categories.contains { $0.id == categoryID }
    }

    private var verticalDivider: some View {
        Divider()
            .overlay(MonMonTheme.border)
            .padding(.vertical, 10)
    }

    private var horizontalDivider: some View {
        Divider()
            .overlay(MonMonTheme.border)
    }

    private var nameField: some View {
        TextField("Name", text: $draft.symbol)
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .accessibilityLabel(Text(draft.slot.nameFieldLabel))
            .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-symbol")
    }

    private var amountField: some View {
        VNDTextField("Price", text: $draft.amountText)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .accessibilityLabel(Text(draft.slot.amountFieldLabel))
            .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-amount")
    }

    @ViewBuilder
    private var categoryField: some View {
        if categories.isEmpty {
            Text("No category")
                .font(.caption)
                .foregroundStyle(MonMonTheme.danger)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        } else {
            Picker("Category", selection: $draft.categoryID) {
                if hasStaleSelection, let categoryID = draft.categoryID {
                    Text("Choose")
                        .tag(UUID?.some(categoryID))
                }

                Text("Transaction default")
                    .tag(UUID?.none)

                ForEach(categories) { category in
                    Label(category.name, systemImage: category.symbolName)
                        .tag(UUID?.some(category.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .accessibilityIdentifier(
                "quick-expense-\(draft.slot.rawValue)-category"
            )
        }
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

    var nameFieldLabel: LocalizedStringResource {
        switch self {
        case .coffee: "Coffee name"
        case .lunch: "Lunch name"
        case .fuel: "Fuel name"
        case .groceries: "Groceries name"
        case .parking: "Parking name"
        case .transit: "Transit name"
        case .medicine: "Medicine name"
        case .entertainment: "Entertainment name"
        case .bills: "Bills name"
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
