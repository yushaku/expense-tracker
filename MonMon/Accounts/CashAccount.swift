import Foundation
import SwiftData

@Model
final class CashAccount {
    var id: UUID
    var name: String
    var kind: CashAccountKind
    var openingBalance: Decimal
    var currencyCode: String
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        kind: CashAccountKind,
        openingBalance: Decimal,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.openingBalance = openingBalance
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}
