import Foundation

enum FundFormError: Error, Equatable {
    case missingInstrument
    case invalidUnits
    case nonPositiveUnits
    case invalidAverageCost
    case nonPositiveAverageCost
    case insufficientSourceBalance
}

/// Validates a position before any `FundHolding` is written.
///
/// The name, the ticker, the kind, and the price are no longer here: they
/// belong to the instrument, and the form picks one rather than retyping them.
/// What remains is what a position actually is.
struct FundDraft: Equatable {
    var instrumentID: UUID?
    var unitsText: String
    var averageCostText: String
    var sourceAccountID: UUID?

    init(
        instrumentID: UUID? = nil,
        unitsText: String = "",
        averageCostText: String = "",
        sourceAccountID: UUID? = nil
    ) {
        self.instrumentID = instrumentID
        self.unitsText = unitsText
        self.averageCostText = averageCostText
        self.sourceAccountID = sourceAccountID
    }

    init(holding: FundHolding) {
        self.init(
            instrumentID: holding.instrumentID,
            unitsText: UnitQuantity.format(holding.units),
            averageCostText: VNDCurrency.formatPlain(holding.averageCostPerUnit),
            sourceAccountID: holding.sourceAccountID
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var instrumentID: UUID
        var units: Decimal
        var averageCostPerUnit: Decimal

        var costBasis: Decimal {
            FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
        }
    }

    /// - Parameter availableSourceBalance: spendable balance of the selected
    ///   source account, or `nil` when the holding is not funded from one.
    ///   When editing, the caller adds this holding's current cost basis back so
    ///   re-saving unchanged values never reports an overdraft.
    func validate(availableSourceBalance: Decimal?) throws -> ValidatedValues {
        guard let instrumentID else {
            throw FundFormError.missingInstrument
        }

        guard let units = UnitQuantity.parse(unitsText) else {
            throw FundFormError.invalidUnits
        }

        guard units > 0 else {
            throw FundFormError.nonPositiveUnits
        }

        guard let averageCostPerUnit = VNDCurrency.parse(averageCostText) else {
            throw FundFormError.invalidAverageCost
        }

        guard averageCostPerUnit > 0 else {
            throw FundFormError.nonPositiveAverageCost
        }

        let values = ValidatedValues(
            instrumentID: instrumentID,
            units: units,
            averageCostPerUnit: averageCostPerUnit
        )

        if let availableSourceBalance, values.costBasis > availableSourceBalance {
            throw FundFormError.insufficientSourceBalance
        }

        return values
    }

    func makeHolding(
        id: UUID,
        createdAt: Date,
        availableSourceBalance: Decimal?
    ) throws -> FundHolding {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        return FundHolding(
            id: id,
            instrumentID: values.instrumentID,
            units: values.units,
            averageCostPerUnit: values.averageCostPerUnit,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )
    }

    func apply(
        to holding: FundHolding,
        availableSourceBalance: Decimal?
    ) throws {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        holding.instrumentID = values.instrumentID
        holding.units = values.units
        holding.averageCostPerUnit = values.averageCostPerUnit
        holding.sourceAccountID = sourceAccountID
    }
}
