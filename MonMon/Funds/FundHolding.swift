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
    /// Optional, and for a reason that has nothing to do with what a position
    /// is: CloudKit needs every attribute optional or defaulted, and an
    /// instrument has no sensible placeholder to default to. A seeded stand-in
    /// would carry a made-up ticker and a zero price, and it would show up in
    /// the picker every time a holding is added — the cure being worse than the
    /// disease. `FundDraft` still requires a choice, so nothing the app writes
    /// leaves this empty.
    ///
    /// The catalogue is joined in Swift rather than through a SwiftData
    /// relationship, so this can also name an instrument that has since been
    /// deleted. Either way `FundSummary.unpriced` reports the position rather
    /// than valuing it at a price it does not have.
    var instrumentID: UUID?
    var units: Decimal = Decimal.zero
    var averageCostPerUnit: Decimal = Decimal.zero

    /// Identifier of the cash account this holding was bought from, if any.
    /// A stored id keeps the model flat; SwiftData relationships are not needed
    /// because an account cannot be deleted while it funds a holding.
    var sourceAccountID: UUID?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    /// The day the units were bought, which is rarely the day they were typed
    /// in: a DCA stack is often entered weeks after the purchases it records.
    ///
    /// Optional rather than defaulted, because there is no honest default for a
    /// record written before this field existed. `boughtOn` falls back to
    /// `createdAt` for those, which is the closest thing that build knew.
    var purchasedAt: Date?

    init(
        id: UUID,
        instrumentID: UUID?,
        units: Decimal,
        averageCostPerUnit: Decimal,
        createdAt: Date,
        sourceAccountID: UUID? = nil,
        purchasedAt: Date? = nil
    ) {
        self.id = id
        self.instrumentID = instrumentID
        self.units = units
        self.averageCostPerUnit = averageCostPerUnit
        self.createdAt = createdAt
        self.sourceAccountID = sourceAccountID
        self.purchasedAt = purchasedAt
    }
}

extension FundHolding {
    /// The day this position was bought. Records written before the app asked
    /// for one report the day they were entered instead, which is what those
    /// builds meant by it.
    var boughtOn: Date {
        purchasedAt ?? createdAt
    }

    /// What this position cost when it was bought, whether or not any of it has
    /// since been sold.
    ///
    /// Needs no instrument: the price paid is the owner's own figure and never
    /// moves with the market. This is also the amount deducted from the funding
    /// account, which is why the cash side of the app is untouched by a price
    /// refresh — and why selling must not shrink it. That deduction records a
    /// payment that already happened; a sale adds its proceeds separately, and
    /// shrinking this as well would hand the cost back twice.
    var costBasis: Decimal {
        FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
    }

    /// What is still held here, once every sale out of this lot is taken off.
    func remainingUnits(sales: [FundSale]) -> Decimal {
        FundSaleSummary.remainingUnits(of: self, sales: sales)
    }

    /// What the units still held cost. The figure the open part of the position
    /// is measured against — unlike `costBasis`, which stays whole because the
    /// cash side is settled against it.
    func remainingCostBasis(sales: [FundSale]) -> Decimal {
        FundValuation.costBasis(
            units: remainingUnits(sales: sales),
            averageCostPerUnit: averageCostPerUnit
        )
    }

    func realizedProfitLoss(sales: [FundSale]) -> Decimal {
        FundSaleSummary.realizedProfitLoss(for: self, sales: sales)
    }

    /// Valuation takes the price as a value rather than reading a model, so
    /// `FundValuation` stays pure and a caller cannot accidentally value a
    /// position against another instrument's price. It takes the sales too,
    /// because only what is still held has a market value at all.
    func marketValue(pricePerUnit: Decimal, sales: [FundSale]) -> Decimal {
        FundValuation.marketValue(
            units: remainingUnits(sales: sales),
            pricePerUnit: pricePerUnit
        )
    }

    func unrealizedProfitLoss(pricePerUnit: Decimal, sales: [FundSale]) -> Decimal {
        FundValuation.unrealizedProfitLoss(
            units: remainingUnits(sales: sales),
            averageCostPerUnit: averageCostPerUnit,
            pricePerUnit: pricePerUnit
        )
    }

    func returnPercent(pricePerUnit: Decimal, sales: [FundSale]) -> Decimal {
        FundValuation.returnPercent(
            units: remainingUnits(sales: sales),
            averageCostPerUnit: averageCostPerUnit,
            pricePerUnit: pricePerUnit
        )
    }

    /// Convenience for the common case where the catalogue is already to hand.
    /// A holding whose instrument is missing is worth nothing rather than
    /// crashing; the card renders that state explicitly.
    func marketValue(in instruments: [FundInstrument], sales: [FundSale]) -> Decimal {
        marketValue(
            pricePerUnit: instruments.matching(self)?.currentPricePerUnit ?? .zero,
            sales: sales
        )
    }
}
