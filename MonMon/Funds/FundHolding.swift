import Foundation
import SwiftData

@Model
final class FundHolding {
    var id: UUID
    var name: String
    /// Uppercased ticker, e.g. `FUEVFVND`.
    var symbol: String
    var kind: FundHoldingKind
    var units: Decimal
    var averageCostPerUnit: Decimal
    /// Latest price per unit, entered by hand. No network in this slice.
    var currentNAVPerUnit: Decimal
    var navAsOf: Date
    var currencyCode: String
    var createdAt: Date
    /// Identifier of the cash account this holding was bought from, if any.
    /// A stored id keeps the model flat; SwiftData relationships are not needed
    /// because accounts are never deleted in this slice.
    var sourceAccountID: UUID?

    init(
        id: UUID,
        name: String,
        symbol: String,
        kind: FundHoldingKind,
        units: Decimal,
        averageCostPerUnit: Decimal,
        currentNAVPerUnit: Decimal,
        navAsOf: Date,
        currencyCode: String,
        createdAt: Date,
        sourceAccountID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.kind = kind
        self.units = units
        self.averageCostPerUnit = averageCostPerUnit
        self.currentNAVPerUnit = currentNAVPerUnit
        self.navAsOf = navAsOf
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.sourceAccountID = sourceAccountID
    }
}

extension FundHolding {
    var costBasis: Decimal {
        FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
    }

    var marketValue: Decimal {
        FundValuation.marketValue(units: units, currentNAVPerUnit: currentNAVPerUnit)
    }

    var unrealizedProfitLoss: Decimal {
        FundValuation.unrealizedProfitLoss(
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit
        )
    }

    var returnPercent: Decimal {
        FundValuation.returnPercent(
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit
        )
    }
}
