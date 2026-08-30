import Foundation
import SwiftData

/// An earmark inside a budget jar, not a second financial balance.
@Model
final class FinancialGoal {
    var id: UUID = UUID()
    var name: String = ""
    var targetAmount: Decimal = Decimal.zero
    var earmarkedAmount: Decimal = Decimal.zero
    var targetDate: Date = Date(timeIntervalSince1970: 0)
    var monthlyContribution: Decimal = Decimal.zero
    var fundingJarID: UUID?
    var symbolName: String = CategoryPalette.defaultSymbolName
    var colorName: String = CategoryPalette.defaultColorName
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        name: String,
        targetAmount: Decimal,
        earmarkedAmount: Decimal,
        targetDate: Date,
        monthlyContribution: Decimal,
        fundingJarID: UUID?,
        symbolName: String,
        colorName: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.earmarkedAmount = earmarkedAmount
        self.targetDate = targetDate
        self.monthlyContribution = monthlyContribution
        self.fundingJarID = fundingJarID
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
        self.createdAt = createdAt
    }
}
