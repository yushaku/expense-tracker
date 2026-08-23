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
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        name: String,
        kind: TransactionKind,
        symbolName: String,
        colorName: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.symbolName = symbolName
        self.colorName = colorName
        self.createdAt = createdAt
    }
}
