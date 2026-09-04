import Foundation
import SwiftData

/// One sale out of one `FundHolding`: how many units left the position, at what
/// price, and into which account the money landed.
///
/// ## Why the lot is never rewritten
///
/// Selling does not shrink the holding it came out of. `units` and
/// `averageCostPerUnit` stay exactly as they were bought, and what is still held
/// is derived — `units` minus everything sold. That is the same rule
/// `CashAccount.openingBalance` follows, and it buys three things a shrinking
/// lot cannot:
///
/// - The cash maths needs no new terms. `CashBalanceSummary.fundedAmount` keeps
///   subtracting the original cost basis, because that is genuinely the money
///   that left the account on the day of purchase, and this record adds the
///   proceeds back. Over a full round trip the account moves by the realized
///   profit and nothing is counted twice.
/// - `AssetHistory` can still reconstruct a past month, because a sale is dated
///   and can be filtered out of it the way a purchase already is.
/// - What was bought stays legible after it is gone.
///
/// Like `AccountTransfer` and `DebtPayment` this carries no category and stays
/// out of the Spending totals: selling is an asset turning into cash, not
/// income. The gain it realizes was already in net worth as an unrealized one.
@Model
final class FundSale {
    var id: UUID = UUID()
    /// Identifier of the `FundHolding` these units came out of.
    ///
    /// Optional for the reason every identifier here is optional — CloudKit
    /// needs each attribute optional or defaulted, and a lot has no placeholder
    /// worth seeding. Nothing computable survives without it: the cost the sale
    /// is measured against lives on the lot, so a sale naming none is skipped
    /// rather than guessed at, exactly as `DebtSummary.netFlow` skips a payment
    /// naming no debt.
    var holdingID: UUID?
    /// Always positive, and in the unit the lot is stored in — lượng for gold,
    /// never chỉ. The form converts; the store does not.
    var units: Decimal = Decimal.zero
    /// What one unit fetched. The owner's own figure, so a later price refresh
    /// cannot move a sale that already happened.
    var pricePerUnit: Decimal = Decimal.zero
    /// A fee or deduction charged when this sale was completed.
    var fee: Decimal = Decimal.zero
    /// Identifier of the cash account the proceeds landed in. Required, for the
    /// reason `DebtPayment.accountID` is: a sale that moves no money is not a
    /// sale, it is a smaller position, and that is an edit to the lot.
    ///
    /// Meaningless on a swap, where no cash account is involved at all. See
    /// `swapHoldingID`, which is what every cash reader checks first.
    var proceedsAccountID: UUID = AccountSeed.unassignedID
    /// The lot this sale bought, when it was a swap rather than a sale for cash.
    ///
    /// Most coin trading is not a sale into a bank account: one coin is
    /// exchanged for another, usually a stablecoin, and no đồng moves anywhere.
    /// Such a trade is still a disposal — the units leave the lot and the gain
    /// on them is settled — so it is recorded as a sale. What it must not do is
    /// pay into an account, because nothing arrived in one.
    ///
    /// This is the flag for that, and the link between the two legs at the same
    /// time. `FundSaleSummary.netFlow` and `count(for:)` skip a sale carrying
    /// one, so the swap's value stays entirely inside the portfolio: the units
    /// sold stop being worth anything and the lot named here starts.
    ///
    /// `nil` for an ordinary sale, which is every sale written before swaps
    /// existed.
    var swapHoldingID: UUID?
    var soldAt: Date = Date(timeIntervalSince1970: 0)
    var note: String = ""
    var currencyCode: String = VNDCurrency.code
    /// Đồng per dollar, when the price was typed in dollars. `pricePerUnit` is
    /// đồng either way; this only records how that figure was arrived at, so
    /// reopening the editor shows what was typed. `nil` for a price typed in
    /// đồng. See `FundHolding.purchaseExchangeRate`.
    var exchangeRate: Decimal?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        holdingID: UUID?,
        units: Decimal,
        pricePerUnit: Decimal,
        fee: Decimal = .zero,
        proceedsAccountID: UUID,
        soldAt: Date,
        note: String = "",
        currencyCode: String = VNDCurrency.code,
        exchangeRate: Decimal? = nil,
        swapHoldingID: UUID? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.holdingID = holdingID
        self.units = units
        self.pricePerUnit = pricePerUnit
        self.fee = fee
        self.proceedsAccountID = proceedsAccountID
        self.soldAt = soldAt
        self.note = note
        self.currencyCode = currencyCode
        self.exchangeRate = exchangeRate
        self.swapHoldingID = swapHoldingID
        self.createdAt = createdAt
    }
}

extension FundSale {
    /// Whether this disposal exchanged one coin for another rather than paying
    /// into a cash account.
    var isSwap: Bool {
        swapHoldingID != nil
    }

    /// The dollar price this sale was entered at, when it was entered in
    /// dollars. Derived, so it can never disagree with the đồng that reached
    /// the account.
    var pricePerUnitInDollars: Decimal? {
        guard let exchangeRate else {
            return nil
        }
        return USDPrice.inDollars(pricePerUnit, rate: exchangeRate)
    }

    /// Sale value before fees, rounded to the đồng.
    var grossProceeds: Decimal {
        FundValuation.marketValue(units: units, pricePerUnit: pricePerUnit)
    }

    /// What actually reaches the cash account after the sale fee.
    var proceeds: Decimal {
        grossProceeds - fee
    }

    /// What the sold units cost, given the lot they came out of. The cost is
    /// passed in rather than stored for the reason `DebtPayment.signedAmount`
    /// takes its direction from the debt: a sale and its lot can then never
    /// disagree about what the units were bought for.
    func costBasis(costPerUnit: Decimal) -> Decimal {
        FundValuation.costBasis(units: units, averageCostPerUnit: costPerUnit)
    }

    func realizedProfitLoss(costPerUnit: Decimal) -> Decimal {
        proceeds - costBasis(costPerUnit: costPerUnit)
    }
}
