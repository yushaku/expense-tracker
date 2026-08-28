import Foundation

struct QuickExpensePresetDraft: Equatable, Identifiable {
    let slot: QuickExpenseSlot
    var symbol: String
    var amountText: String

    var id: QuickExpenseSlot { slot }

    init(preset: QuickExpensePreset) {
        slot = preset.slot
        symbol = preset.symbol
        amountText = VNDCurrency.formatPlain(preset.amount)
    }

    func makePreset() throws -> QuickExpensePreset {
        guard let amount = VNDCurrency.parse(amountText) else {
            throw QuickExpensePresetError.invalidAmount
        }
        return try QuickExpensePreset(slot: slot, symbol: symbol, amount: amount)
    }
}
