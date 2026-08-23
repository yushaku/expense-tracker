import Foundation
import SwiftData

@Model
final class TransactionCategory {
    var id: UUID
    var name: String
    var kind: TransactionKind
    /// Always written from `CategoryPalette`, so restyling the palette can never
    /// leave a record that will not render.
    var symbolName: String
    var colorName: String
    var createdAt: Date

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
