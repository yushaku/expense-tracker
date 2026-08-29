import Foundation
import SwiftData

enum BudgetJarRole: String, Codable, CaseIterable {
    case custom
    case investment
    case savings
}

@Model
final class BudgetJar {
    var id: UUID = UUID()
    var name: String = ""
    var allocationPercent: Decimal = Decimal.zero
    var role: BudgetJarRole = BudgetJarRole.custom
    var symbolName: String = CategoryPalette.defaultSymbolName
    var colorName: String = CategoryPalette.defaultColorName
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        name: String,
        allocationPercent: Decimal,
        role: BudgetJarRole,
        symbolName: String,
        colorName: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.allocationPercent = allocationPercent
        self.role = role
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
        self.createdAt = createdAt
    }

    var isProtected: Bool {
        role == .savings || role == .investment
    }
}

enum BudgetJarRouting {
    static func fallback(
        in jars: [BudgetJar],
        excluding excludedID: UUID? = nil
    ) -> BudgetJar? {
        let available = jars.filter { $0.id != excludedID }
        return available.first { $0.id == BudgetJarSeed.necessitiesID }
            ?? available.first { $0.role == .custom }
            ?? available.first
    }
}
