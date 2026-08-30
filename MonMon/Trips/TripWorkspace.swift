import Foundation
import SwiftData

enum TripWorkspaceStatus: String, Codable, CaseIterable {
    case active
    case completed
}

/// A spending lens over ordinary expense transactions, not a financial balance.
@Model
final class TripWorkspace {
    var id: UUID = UUID()
    var sourceGoalID: UUID?
    var name: String = ""
    var budgetAmount: Decimal = Decimal.zero
    var fundingJarID: UUID?
    var symbolName: String = CategoryPalette.defaultSymbolName
    var colorName: String = CategoryPalette.defaultColorName
    var status: TripWorkspaceStatus = TripWorkspaceStatus.active
    var startedAt: Date = Date(timeIntervalSince1970: 0)
    var completedAt: Date?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        sourceGoalID: UUID?,
        name: String,
        budgetAmount: Decimal,
        fundingJarID: UUID?,
        symbolName: String,
        colorName: String,
        status: TripWorkspaceStatus,
        startedAt: Date,
        completedAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.sourceGoalID = sourceGoalID
        self.name = name
        self.budgetAmount = budgetAmount
        self.fundingJarID = fundingJarID
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}
