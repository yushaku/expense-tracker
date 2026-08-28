import Foundation

enum FundSaleFormError: Error, Equatable {
    case invalidUnits
    case nonPositiveUnits
    case exceedsRemainingUnits
    case invalidPrice
    case nonPositivePrice
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
    @VNDInput var pricePerUnitText: String
    var soldAt: Date
    var proceedsAccountID: UUID?
    var note: String

    init(
        unitsText: String = "",
        pricePerUnitText: String = "",
        soldAt: Date,
        proceedsAccountID: UUID? = nil,
        note: String = ""
    ) {
        self.unitsText = unitsText
        self.pricePerUnitText = pricePerUnitText
        self.soldAt = soldAt
        self.proceedsAccountID = proceedsAccountID
        self.note = note
    }

    init(sale: FundSale) {
        self.init(
            unitsText: UnitQuantity.format(sale.units),
            pricePerUnitText: VNDCurrency.formatPlain(sale.pricePerUnit),
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
        var pricePerUnit: Decimal
        var soldAt: Date
        var proceedsAccountID: UUID
        var note: String

        var proceeds: Decimal {
            FundValuation.marketValue(units: units, pricePerUnit: pricePerUnit)
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

        guard let pricePerUnit = VNDCurrency.parse(pricePerUnitText) else {
            throw FundSaleFormError.invalidPrice
        }

        guard pricePerUnit > 0 else {
            throw FundSaleFormError.nonPositivePrice
        }

        guard let proceedsAccountID else {
            throw FundSaleFormError.missingAccount
        }

        return ValidatedValues(
            units: units,
            pricePerUnit: pricePerUnit,
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
            proceedsAccountID: values.proceedsAccountID,
            soldAt: values.soldAt,
            note: values.note,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    func apply(to sale: FundSale, remainingUnits: Decimal) throws {
        let values = try validate(remainingUnits: remainingUnits)

        sale.units = values.units
        sale.pricePerUnit = values.pricePerUnit
        sale.soldAt = values.soldAt
        sale.proceedsAccountID = values.proceedsAccountID
        sale.note = values.note
    }
}
