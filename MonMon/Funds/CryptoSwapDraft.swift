import Foundation

enum CryptoSwapFormError: Error, Equatable {
    case invalidUnitsGiven
    case nonPositiveUnitsGiven
    case exceedsRemainingUnits
    case missingReceivedInstrument
    case sameInstrument
    case invalidUnitsReceived
    case nonPositiveUnitsReceived
    case invalidValue
    case nonPositiveValue
    case invalidExchangeRate
    case nonPositiveExchangeRate
}

/// Validates one coin being exchanged for another before either leg is written.
///
/// ## Why a swap is two records and not one
///
/// Most coin trading never touches a bank. One coin is exchanged for another,
/// usually a stablecoin, and no đồng moves anywhere. That is still a disposal:
/// the units leave the lot for good and whatever they had gained is settled at
/// that moment. So a swap is recorded as what it is — a sale of the coin given
/// and a new lot in the coin received — rather than as a fourth kind of record
/// that every summary would have to learn about.
///
/// ## Why one value anchors both legs
///
/// The sale's gross proceeds and the new lot's cost basis are the same number
/// by construction, taken from a single field. Letting the two be typed apart
/// would let a swap create or destroy value: net worth would move on a trade
/// where nothing entered or left the portfolio.
///
/// Gross, not net. `FundSale.proceeds` subtracts whatever fee the sale
/// carried, and a fee is a cost of trading rather than a change in what the
/// trade was booked at. Reading the net figure back would shrink the value on
/// every reopen while the lot it bought kept the gross one, and the two legs
/// would drift apart a fee at a time. Coins carry no fee today — the policy
/// gives them none — so this is a guard on the shape rather than on today's
/// behaviour.
///
/// Nothing here writes to a cash account. `FundSale.swapHoldingID` marks the
/// sale so `FundSaleSummary.netFlow` skips it, and the new lot names no funding
/// account, so `CashBalanceSummary.fundedAmount` skips it too.
struct CryptoSwapDraft: Equatable {
    /// How much of the lot is being given up, in the unit it is stored in.
    var unitsGivenText: String
    /// The instrument being received. The one being given comes from the lot
    /// the editor was opened on, so it is never in doubt.
    var receivedInstrumentID: UUID?
    var unitsReceivedText: String
    /// What the trade was worth, as typed, in whichever currency
    /// `valueCurrency` names. Both legs are settled from this one figure.
    var valueText: String
    var valueCurrency: PriceEntryCurrency
    /// Đồng per dollar, read only while `valueCurrency` is `.usd`.
    var exchangeRateText: String
    var swappedAt: Date
    var note: String

    init(
        unitsGivenText: String = "",
        receivedInstrumentID: UUID? = nil,
        unitsReceivedText: String = "",
        valueText: String = "",
        valueCurrency: PriceEntryCurrency = .vnd,
        exchangeRateText: String = "",
        swappedAt: Date,
        note: String = ""
    ) {
        self.unitsGivenText = unitsGivenText
        self.receivedInstrumentID = receivedInstrumentID
        self.unitsReceivedText = unitsReceivedText
        self.valueText = valueText
        self.valueCurrency = valueCurrency
        self.exchangeRateText = exchangeRateText
        self.swappedAt = swappedAt
        self.note = note
    }

    /// Reopens a recorded swap from its two legs.
    ///
    /// Takes both because neither carries the whole trade: the sale knows what
    /// was given and what it was worth, and only the lot knows what came back.
    init(sale: FundSale, received: FundHolding) {
        let value = sale.grossProceeds

        if let rate = sale.exchangeRate, let dollars = USDPrice.inDollars(value, rate: rate) {
            self.init(
                unitsGivenText: UnitQuantity.format(sale.units),
                receivedInstrumentID: received.instrumentID,
                unitsReceivedText: UnitQuantity.format(received.units),
                valueText: USDPrice.format(dollars),
                valueCurrency: .usd,
                exchangeRateText: VNDCurrency.formatPlain(rate),
                swappedAt: sale.soldAt,
                note: sale.note
            )
            return
        }

        self.init(
            unitsGivenText: UnitQuantity.format(sale.units),
            receivedInstrumentID: received.instrumentID,
            unitsReceivedText: UnitQuantity.format(received.units),
            valueText: VNDCurrency.formatPlain(value),
            swappedAt: sale.soldAt,
            note: sale.note
        )
    }

    struct ValidatedValues: Equatable {
        var unitsGiven: Decimal
        var receivedInstrumentID: UUID
        var unitsReceived: Decimal
        /// The trade's worth in đồng. Both legs are derived from it.
        var value: Decimal
        /// The rate that produced `value`, or `nil` when it was typed in đồng.
        var exchangeRate: Decimal?
        var swappedAt: Date
        var note: String

        /// What one unit given fetched. The sale's price, so its realized
        /// profit is measured the same way every other sale's is.
        var pricePerUnitGiven: Decimal {
            value / unitsGiven
        }

        /// What one unit received cost. The new lot's cost basis per unit.
        var costPerUnitReceived: Decimal {
            value / unitsReceived
        }
    }

    /// - Parameters:
    ///   - remainingUnits: what is still held in the lot being swapped out of.
    ///     A swap may no more take it past zero than a sale may.
    ///   - givenInstrumentID: the lot's instrument, so a swap into the same
    ///     thing is refused. Exchanging a coin for itself is not a trade, and
    ///     recording it would settle a gain against no change of position.
    func validate(
        remainingUnits: Decimal,
        givenInstrumentID: UUID?
    ) throws -> ValidatedValues {
        guard let unitsGiven = UnitQuantity.parse(unitsGivenText) else {
            throw CryptoSwapFormError.invalidUnitsGiven
        }

        guard unitsGiven > 0 else {
            throw CryptoSwapFormError.nonPositiveUnitsGiven
        }

        guard unitsGiven <= remainingUnits else {
            throw CryptoSwapFormError.exceedsRemainingUnits
        }

        guard let receivedInstrumentID else {
            throw CryptoSwapFormError.missingReceivedInstrument
        }

        guard receivedInstrumentID != givenInstrumentID else {
            throw CryptoSwapFormError.sameInstrument
        }

        guard let unitsReceived = UnitQuantity.parse(unitsReceivedText) else {
            throw CryptoSwapFormError.invalidUnitsReceived
        }

        guard unitsReceived > 0 else {
            throw CryptoSwapFormError.nonPositiveUnitsReceived
        }

        let value = try validatedValue()

        return ValidatedValues(
            unitsGiven: unitsGiven,
            receivedInstrumentID: receivedInstrumentID,
            unitsReceived: unitsReceived,
            value: value.amount,
            exchangeRate: value.exchangeRate,
            swappedAt: swappedAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// The trade's worth in đồng, and the rate that got it there. Converted
    /// once, here, exactly as the holding and sale drafts do it.
    private func validatedValue() throws -> (amount: Decimal, exchangeRate: Decimal?) {
        switch valueCurrency {
        case .vnd:
            guard let amount = VNDCurrency.parse(valueText) else {
                throw CryptoSwapFormError.invalidValue
            }
            guard amount > 0 else {
                throw CryptoSwapFormError.nonPositiveValue
            }
            return (amount, nil)

        case .usd:
            guard let dollars = USDPrice.parse(valueText) else {
                throw CryptoSwapFormError.invalidValue
            }
            guard dollars > 0 else {
                throw CryptoSwapFormError.nonPositiveValue
            }
            guard let rate = VNDCurrency.parse(exchangeRateText) else {
                throw CryptoSwapFormError.invalidExchangeRate
            }
            guard rate > 0 else {
                throw CryptoSwapFormError.nonPositiveExchangeRate
            }
            guard let amount = USDPrice.inDong(dollars, rate: rate) else {
                throw CryptoSwapFormError.invalidValue
            }
            return (amount, rate)
        }
    }

    /// Both legs of a new swap, already pointing at each other.
    ///
    /// Returned together rather than inserted here, so the caller writes them
    /// in one save. Half a swap is worse than none: a sale with no lot behind
    /// it would take units out of the portfolio and put nothing back.
    func makeSwap(
        givenHolding: FundHolding,
        remainingUnits: Decimal,
        createdAt: Date,
        saleID: UUID = UUID(),
        receivedHoldingID: UUID = UUID()
    ) throws -> (sale: FundSale, received: FundHolding) {
        let values = try validate(
            remainingUnits: remainingUnits,
            givenInstrumentID: givenHolding.instrumentID
        )

        let received = FundHolding(
            id: receivedHoldingID,
            instrumentID: values.receivedInstrumentID,
            units: values.unitsReceived,
            averageCostPerUnit: values.costPerUnitReceived,
            createdAt: createdAt,
            // No cash bought this, so no account is named and
            // `CashBalanceSummary.fundedAmount` leaves it alone.
            sourceAccountID: nil,
            purchasedAt: values.swappedAt,
            purchaseExchangeRate: values.exchangeRate
        )

        let sale = FundSale(
            id: saleID,
            holdingID: givenHolding.id,
            units: values.unitsGiven,
            pricePerUnit: values.pricePerUnitGiven,
            // Carried only because the field cannot be absent. Nothing reads it
            // while `swapHoldingID` is set.
            proceedsAccountID: AccountSeed.unassignedID,
            soldAt: values.swappedAt,
            note: values.note,
            currencyCode: VNDCurrency.code,
            exchangeRate: values.exchangeRate,
            swapHoldingID: receivedHoldingID,
            createdAt: createdAt
        )

        return (sale, received)
    }

    /// Rewrites both legs of a swap already recorded.
    func apply(
        to sale: FundSale,
        received: FundHolding,
        givenHolding: FundHolding,
        remainingUnits: Decimal
    ) throws {
        let values = try validate(
            remainingUnits: remainingUnits,
            givenInstrumentID: givenHolding.instrumentID
        )

        received.instrumentID = values.receivedInstrumentID
        received.units = values.unitsReceived
        received.averageCostPerUnit = values.costPerUnitReceived
        received.purchasedAt = values.swappedAt
        received.purchaseExchangeRate = values.exchangeRate

        sale.units = values.unitsGiven
        sale.pricePerUnit = values.pricePerUnitGiven
        sale.soldAt = values.swappedAt
        sale.note = values.note
        sale.exchangeRate = values.exchangeRate
        sale.swapHoldingID = received.id
    }
}

extension CryptoSwapDraft {
    /// The lot a swap bought, given every lot there is. `nil` when the sale is
    /// an ordinary one, or when the lot it named has since been deleted.
    static func receivedHolding(for sale: FundSale, in holdings: [FundHolding]) -> FundHolding? {
        guard let swapHoldingID = sale.swapHoldingID else {
            return nil
        }
        return holdings.first { $0.id == swapHoldingID }
    }

    /// The swap that bought this lot, given every sale there is. Resolved by
    /// searching rather than by a second stored identifier, the way every other
    /// join in this schema is.
    static func swapSale(forHoldingID id: UUID, in sales: [FundSale]) -> FundSale? {
        sales.first { $0.swapHoldingID == id }
    }
}
