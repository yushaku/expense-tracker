import Foundation

enum FundSaleFormError: Error, Equatable {
    case invalidUnits
    case nonPositiveUnits
    case exceedsRemainingUnits
    case invalidPrice
    case nonPositivePrice
    case invalidExchangeRate
    case nonPositiveExchangeRate
    case invalidFee
    case negativeFee
    case feeExceedsProceeds
    case missingAccount
}

/// Validates a sale before any `FundSale` is written.
///
/// Takes the units still held as a scalar rather than the lot and its sales, so
/// it depends on neither `FundHolding` nor `FundSaleSummary` and stays testable
/// without a `ModelContext` — the same shape `DebtPaymentDraft` has for the same
/// reason.
struct FundSaleDraft: Equatable {
    var unitsText: String
    /// The price, as typed, in whichever currency `priceCurrency` names.
    var pricePerUnitText: String
    /// Which currency `pricePerUnitText` is in. See `FundDraft.costCurrency`.
    var priceCurrency: PriceEntryCurrency
    /// Which unit gold is being typed in. Ignored by every other kind,
    /// which has only one unit to offer.
    var goldUnit: GoldUnit
    /// Đồng per dollar, as typed. Read only while `priceCurrency` is `.usd`.
    var exchangeRateText: String
    var feeText: String
    var soldAt: Date
    var proceedsAccountID: UUID?
    var note: String

    init(
        unitsText: String = "",
        pricePerUnitText: String = "",
        priceCurrency: PriceEntryCurrency = .vnd,
        goldUnit: GoldUnit = .chi,
        exchangeRateText: String = "",
        feeText: String = "",
        soldAt: Date,
        proceedsAccountID: UUID? = nil,
        note: String = ""
    ) {
        self.unitsText = unitsText
        self.pricePerUnitText = pricePerUnitText
        self.priceCurrency = priceCurrency
        self.goldUnit = goldUnit
        self.exchangeRateText = exchangeRateText
        self.feeText = feeText
        self.soldAt = soldAt
        self.proceedsAccountID = proceedsAccountID
        self.note = note
    }

    /// Reopens a sale in the currency it was entered in, at the rate it was
    /// written with. See `FundDraft.init(holding:)` for why.
    init(sale: FundSale) {
        if let rate = sale.exchangeRate, let dollars = sale.pricePerUnitInDollars {
            self.init(
                unitsText: UnitQuantity.format(sale.units),
                pricePerUnitText: USDPrice.format(dollars),
                priceCurrency: .usd,
                exchangeRateText: VNDCurrency.formatPlain(rate),
                feeText: sale.fee > 0 ? VNDCurrency.formatPlain(sale.fee) : "",
                soldAt: sale.soldAt,
                proceedsAccountID: sale.proceedsAccountID,
                note: sale.note
            )
            return
        }

        self.init(
            unitsText: UnitQuantity.format(sale.units),
            pricePerUnitText: VNDCurrency.formatPlain(sale.pricePerUnit),
            feeText: sale.fee > 0 ? VNDCurrency.formatPlain(sale.fee) : "",
            soldAt: sale.soldAt,
            proceedsAccountID: sale.proceedsAccountID,
            note: sale.note
        )
    }

    /// Validated values ready to write to a model. `holdingID` is absent on
    /// purpose: the editor is always opened from one lot, so it travels with
    /// `id` and `createdAt` rather than through the form.
    struct ValidatedValues: Equatable {
        var units: Decimal
        /// Always đồng, whichever currency was typed.
        var pricePerUnit: Decimal
        /// The rate that produced `pricePerUnit`, or `nil` when it was typed in
        /// đồng directly.
        var exchangeRate: Decimal?
        var fee: Decimal
        var soldAt: Date
        var proceedsAccountID: UUID
        var note: String

        var grossProceeds: Decimal {
            FundValuation.marketValue(units: units, pricePerUnit: pricePerUnit)
        }

        var proceeds: Decimal {
            grossProceeds - fee
        }
    }

    /// The sale price in đồng, and the rate that got it there. The conversion
    /// happens once, here, on the way into the store.
    private func validatedPrice() throws -> (perUnit: Decimal, exchangeRate: Decimal?) {
        switch priceCurrency {
        case .vnd:
            guard let perUnit = VNDCurrency.parse(pricePerUnitText) else {
                throw FundSaleFormError.invalidPrice
            }
            guard perUnit > 0 else {
                throw FundSaleFormError.nonPositivePrice
            }
            return (perUnit, nil)

        case .usd:
            guard let dollars = USDPrice.parse(pricePerUnitText) else {
                throw FundSaleFormError.invalidPrice
            }
            guard dollars > 0 else {
                throw FundSaleFormError.nonPositivePrice
            }
            guard let rate = VNDCurrency.parse(exchangeRateText) else {
                throw FundSaleFormError.invalidExchangeRate
            }
            guard rate > 0 else {
                throw FundSaleFormError.nonPositiveExchangeRate
            }
            guard let perUnit = USDPrice.inDong(dollars, rate: rate) else {
                throw FundSaleFormError.invalidPrice
            }
            return (perUnit, rate)
        }
    }

    /// - Parameter remainingUnits: what is still held in the lot. A sale may
    ///   never take it past zero: allowing it would bank proceeds for units the
    ///   owner does not have, and `FundSaleSummary.remainingUnits` deliberately
    ///   does not clamp, so the portfolio would carry a negative position with no
    ///   screen explaining it. When editing, the caller adds this sale's own
    ///   units back, so re-saving unchanged values is never refused.
    func validate(remainingUnits: Decimal) throws -> ValidatedValues {
        guard let units = UnitQuantity.parse(unitsText) else {
            throw FundSaleFormError.invalidUnits
        }

        guard units > 0 else {
            throw FundSaleFormError.nonPositiveUnits
        }

        guard units <= remainingUnits else {
            throw FundSaleFormError.exceedsRemainingUnits
        }

        let price = try validatedPrice()

        let fee: Decimal
        if feeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fee = .zero
        } else {
            guard let parsedFee = VNDCurrency.parse(feeText) else {
                throw FundSaleFormError.invalidFee
            }
            guard parsedFee >= 0 else {
                throw FundSaleFormError.negativeFee
            }
            fee = parsedFee
        }

        let grossProceeds = FundValuation.marketValue(units: units, pricePerUnit: price.perUnit)
        guard fee < grossProceeds else {
            throw FundSaleFormError.feeExceedsProceeds
        }

        guard let proceedsAccountID else {
            throw FundSaleFormError.missingAccount
        }

        return ValidatedValues(
            units: units,
            pricePerUnit: price.perUnit,
            exchangeRate: price.exchangeRate,
            fee: fee,
            soldAt: soldAt,
            proceedsAccountID: proceedsAccountID,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func makeSale(
        id: UUID,
        holdingID: UUID,
        createdAt: Date,
        remainingUnits: Decimal
    ) throws -> FundSale {
        let values = try validate(remainingUnits: remainingUnits)

        return FundSale(
            id: id,
            holdingID: holdingID,
            units: values.units,
            pricePerUnit: values.pricePerUnit,
            fee: values.fee,
            proceedsAccountID: values.proceedsAccountID,
            soldAt: values.soldAt,
            note: values.note,
            currencyCode: VNDCurrency.code,
            exchangeRate: values.exchangeRate,
            createdAt: createdAt
        )
    }

    func apply(to sale: FundSale, remainingUnits: Decimal) throws {
        let values = try validate(remainingUnits: remainingUnits)

        sale.units = values.units
        sale.pricePerUnit = values.pricePerUnit
        // Cleared when the price is retyped in đồng, for the reason
        // `FundDraft.apply(to:availableSourceBalance:)` clears its own.
        sale.exchangeRate = values.exchangeRate
        sale.fee = values.fee
        sale.soldAt = values.soldAt
        sale.proceedsAccountID = values.proceedsAccountID
        sale.note = values.note
    }
}
