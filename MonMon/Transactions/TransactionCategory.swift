import Foundation
import SwiftData

@Model
final class TransactionCategory {
    var id: UUID = UUID()
    var name: String = ""
    var kind: TransactionKind = TransactionKind.expense
    /// Always written from `CategoryPalette`, so restyling the palette can never
    /// leave a record that will not render.
    var symbolName: String = CategoryPalette.defaultSymbolName
    var colorName: String = CategoryPalette.defaultColorName
    /// The budget jar this expense normally uses. Income categories leave it empty.
    var budgetJarID: UUID?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        name: String,
        kind: TransactionKind,
        symbolName: String,
        colorName: String,
        createdAt: Date,
        budgetJarID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.symbolName = symbolName
        self.colorName = colorName
        self.createdAt = createdAt
        self.budgetJarID = budgetJarID
    }
}
