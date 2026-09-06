import Foundation

enum FundFormError: Error, Equatable {
    case missingInstrument
    case invalidUnits
    case nonPositiveUnits
    case invalidAverageCost
    case nonPositiveAverageCost
    case invalidExchangeRate
    case nonPositiveExchangeRate
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
    /// The average cost, as typed, in whichever currency `costCurrency` names.
    var averageCostText: String
    /// Which currency `averageCostText` is in. Đồng unless the owner switched,
    /// which is what every position written before this existed reads as.
    var costCurrency: PriceEntryCurrency
    /// Which unit gold is being typed in. Ignored by every other kind,
    /// which has only one unit to offer.
    var goldUnit: GoldUnit
    /// Đồng per dollar, as typed. Read only while `costCurrency` is `.usd`,
    /// so switching back to đồng cannot leave a stale rate behind.
    var exchangeRateText: String
    var sourceAccountID: UUID?
    /// The day the units were bought. Defaults to whatever the caller passes —
    /// today, for a new position — and can be moved back, because a stack of
    /// monthly purchases is usually entered after the fact.
    var purchasedAt: Date

    init(
        instrumentID: UUID? = nil,
        unitsText: String = "",
        averageCostText: String = "",
        costCurrency: PriceEntryCurrency = .vnd,
        goldUnit: GoldUnit = .chi,
        exchangeRateText: String = "",
        sourceAccountID: UUID? = nil,
        purchasedAt: Date = .now
    ) {
        self.instrumentID = instrumentID
        self.unitsText = unitsText
        self.averageCostText = averageCostText
        self.costCurrency = costCurrency
        self.goldUnit = goldUnit
        self.exchangeRateText = exchangeRateText
        self.sourceAccountID = sourceAccountID
        self.purchasedAt = purchasedAt
    }

    /// Reopens a position in the currency it was entered in.
    ///
    /// A position bought in dollars comes back in dollars, at the rate it was
    /// written with. Showing the converted đồng instead would put a number in
    /// front of the owner that they never typed, and re-saving it would quietly
    /// re-anchor the cost to whatever rate happened to be in the box.
    init(holding: FundHolding) {
        if let rate = holding.purchaseExchangeRate,
            let dollars = holding.averageCostPerUnitInDollars
        {
            self.init(
                instrumentID: holding.instrumentID,
                unitsText: UnitQuantity.format(holding.units),
                averageCostText: USDPrice.format(dollars),
                costCurrency: .usd,
                exchangeRateText: VNDCurrency.formatPlain(rate),
                sourceAccountID: holding.sourceAccountID,
                purchasedAt: holding.boughtOn
            )
            return
        }

        self.init(
            instrumentID: holding.instrumentID,
            unitsText: UnitQuantity.format(holding.units),
            averageCostText: VNDCurrency.formatPlain(holding.averageCostPerUnit),
            sourceAccountID: holding.sourceAccountID,
            purchasedAt: holding.boughtOn
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var instrumentID: UUID
        var units: Decimal
        /// Always đồng, whichever currency was typed.
        var averageCostPerUnit: Decimal
        /// The rate that produced `averageCostPerUnit`, or `nil` when it was
        /// typed in đồng directly.
        var exchangeRate: Decimal?

        var costBasis: Decimal {
            FundValuation.costBasis(units: units, averageCostPerUnit: averageCostPerUnit)
        }
    }

    /// The average cost in đồng, and the rate that got it there.
    ///
    /// The conversion happens once, here, on the way into the store. Nothing
    /// downstream knows a dollar was involved, which is what keeps every total
    /// in the app a single-currency figure.
    private func validatedCost() throws -> (perUnit: Decimal, exchangeRate: Decimal?) {
        switch costCurrency {
        case .vnd:
            guard let perUnit = VNDCurrency.parse(averageCostText) else {
                throw FundFormError.invalidAverageCost
            }
            guard perUnit > 0 else {
                throw FundFormError.nonPositiveAverageCost
            }
            return (perUnit, nil)

        case .usd:
            guard let dollars = USDPrice.parse(averageCostText) else {
                throw FundFormError.invalidAverageCost
            }
            guard dollars > 0 else {
                throw FundFormError.nonPositiveAverageCost
            }
            guard let rate = VNDCurrency.parse(exchangeRateText) else {
                throw FundFormError.invalidExchangeRate
            }
            guard rate > 0 else {
                throw FundFormError.nonPositiveExchangeRate
            }
            guard let perUnit = USDPrice.inDong(dollars, rate: rate) else {
                throw FundFormError.invalidAverageCost
            }
            return (perUnit, rate)
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

        let cost = try validatedCost()

        let values = ValidatedValues(
            instrumentID: instrumentID,
            units: units,
            averageCostPerUnit: cost.perUnit,
            exchangeRate: cost.exchangeRate
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
            sourceAccountID: sourceAccountID,
            purchasedAt: purchasedAt,
            purchaseExchangeRate: values.exchangeRate
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
        holding.purchasedAt = purchasedAt
        // Cleared when the cost is retyped in đồng, so a position never keeps a
        // rate that no longer explains its cost.
        holding.purchaseExchangeRate = values.exchangeRate
    }
}
