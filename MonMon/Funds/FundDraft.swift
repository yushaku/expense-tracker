import Foundation

enum FundFormError: Error, Equatable {
    case emptyName
    case emptySymbol
    case invalidUnits
    case nonPositiveUnits
    case invalidAverageCost
    case nonPositiveAverageCost
    case invalidNAV
    case nonPositiveNAV
    case insufficientSourceBalance
}

struct FundDraft: Equatable {
    var name: String
    var symbol: String
    var kind: FundHoldingKind
    var unitsText: String
    var averageCostText: String
    var navText: String
    var navAsOf: Date
    var sourceAccountID: UUID?

    init(
        name: String = "",
        symbol: String = "",
        kind: FundHoldingKind = .fund,
        unitsText: String = "",
        averageCostText: String = "",
        navText: String = "",
        navAsOf: Date,
        sourceAccountID: UUID? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.kind = kind
        self.unitsText = unitsText
        self.averageCostText = averageCostText
        self.navText = navText
        self.navAsOf = navAsOf
        self.sourceAccountID = sourceAccountID
    }

    init(holding: FundHolding) {
        self.init(
            name: holding.name,
            symbol: holding.symbol,
            kind: holding.kind,
            unitsText: UnitQuantity.format(holding.units),
            averageCostText: VNDCurrency.formatPlain(holding.averageCostPerUnit),
            navText: VNDCurrency.formatPlain(holding.currentNAVPerUnit),
            navAsOf: holding.navAsOf,
            sourceAccountID: holding.sourceAccountID
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var name: String
        var symbol: String
        var kind: FundHoldingKind
        var units: Decimal
        var averageCostPerUnit: Decimal
        var currentNAVPerUnit: Decimal
        var navAsOf: Date

        var costBasis: Decimal {
            FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
        }
    }

    /// - Parameter availableSourceBalance: spendable balance of the selected
    ///   source account, or `nil` when the holding is not funded from one.
    ///   When editing, the caller adds this holding's current cost basis back so
    ///   re-saving unchanged values never reports an overdraft.
    func validate(availableSourceBalance: Decimal?) throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FundFormError.emptyName
        }

        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            throw FundFormError.emptySymbol
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

        guard let currentNAVPerUnit = VNDCurrency.parse(navText) else {
            throw FundFormError.invalidNAV
        }

        guard currentNAVPerUnit > 0 else {
            throw FundFormError.nonPositiveNAV
        }

        let values = ValidatedValues(
            name: trimmedName,
            symbol: trimmedSymbol.uppercased(),
            kind: kind,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit,
            navAsOf: navAsOf
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
            name: values.name,
            symbol: values.symbol,
            kind: values.kind,
            units: values.units,
            averageCostPerUnit: values.averageCostPerUnit,
            currentNAVPerUnit: values.currentNAVPerUnit,
            navAsOf: values.navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )
    }

    func apply(
        to holding: FundHolding,
        availableSourceBalance: Decimal?
    ) throws {
        let values = try validate(availableSourceBalance: availableSourceBalance)

        holding.name = values.name
        holding.symbol = values.symbol
        holding.kind = values.kind
        holding.units = values.units
        holding.averageCostPerUnit = values.averageCostPerUnit
        holding.currentNAVPerUnit = values.currentNAVPerUnit
        holding.navAsOf = values.navAsOf
        holding.sourceAccountID = sourceAccountID
    }
}
