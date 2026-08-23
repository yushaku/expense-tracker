import Foundation
import SwiftData

/// A position in one fund or ETF: how many units, bought at what average cost,
/// funded from which account.
///
/// The instrument's identity and its price used to live here. They moved to
/// `FundInstrument` so one ticker can only ever carry one price, and so several
/// positions in the same thing stay consistent with each other.
@Model
final class FundHolding {
    var id: UUID = UUID()
    /// Identifier of the `FundInstrument` this position is held in.
    ///
    /// Required: a position with no instrument has no identity, no price, and
    /// no way to be valued. The catalogue is still joined in Swift rather than
    /// through a SwiftData relationship, so this can still name an instrument
    /// that has since been deleted — `FundSummary.unpriced` is how the app
    /// reports that, rather than valuing the position at a price it does not
    /// have.
    var instrumentID: UUID
    var units: Decimal = Decimal.zero
    var averageCostPerUnit: Decimal = Decimal.zero

    /// Identifier of the cash account this holding was bought from, if any.
    /// A stored id keeps the model flat; SwiftData relationships are not needed
    /// because an account cannot be deleted while it funds a holding.
    var sourceAccountID: UUID?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        instrumentID: UUID,
        units: Decimal,
        averageCostPerUnit: Decimal,
        createdAt: Date,
        sourceAccountID: UUID? = nil
    ) {
        self.id = id
        self.instrumentID = instrumentID
        self.units = units
        self.averageCostPerUnit = averageCostPerUnit
        self.createdAt = createdAt
        self.sourceAccountID = sourceAccountID
    }
}

extension FundHolding {
    /// What this position cost. Needs no instrument: the price paid is the
    /// owner's own figure and never moves with the market. This is also the
    /// amount deducted from the funding account, which is why the cash side of
    /// the app is untouched by a price refresh.
    var costBasis: Decimal {
        FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
    }

    /// Valuation takes the price as a value rather than reading a model, so
    /// `FundValuation` stays pure and a caller cannot accidentally value a
    /// position against another instrument's price.
    func marketValue(pricePerUnit: Decimal) -> Decimal {
        FundValuation.marketValue(units: units, pricePerUnit: pricePerUnit)
    }

    func unrealizedProfitLoss(pricePerUnit: Decimal) -> Decimal {
        FundValuation.unrealizedProfitLoss(
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            pricePerUnit: pricePerUnit
        )
    }

    func returnPercent(pricePerUnit: Decimal) -> Decimal {
        FundValuation.returnPercent(
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            pricePerUnit: pricePerUnit
        )
    }

    /// Convenience for the common case where the catalogue is already to hand.
    /// A holding whose instrument is missing is worth nothing rather than
    /// crashing; the card renders that state explicitly.
    func marketValue(in instruments: [FundInstrument]) -> Decimal {
        marketValue(pricePerUnit: instruments.matching(self)?.currentPricePerUnit ?? .zero)
    }
}
