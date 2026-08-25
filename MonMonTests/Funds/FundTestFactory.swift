import Foundation

@testable import MonMon

/// Builds a catalogue entry and positions in it.
///
/// Shared because the split means almost every fund test now needs two records
/// where it used to need one, and because a test that hand-rolls the pair is one
/// typo away from valuing a position against another instrument's price.
enum FundTestFactory {
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func instrument(
        symbol: String = "VESAF",
        name: String = "VinaCapital VESAF",
        kind: FundInstrumentKind = .fund,
        pricePerUnit: Decimal,
        priceAsOf: Date = referenceDate,
        source: FundQuoteSource = .manual,
        priceFetchedAt: Date? = nil,
        autoQuoteEnabled: Bool = true,
        id: UUID = UUID()
    ) -> FundInstrument {
        FundInstrument(
            id: id,
            symbol: symbol,
            name: name,
            kind: kind,
            currentPricePerUnit: pricePerUnit,
            priceAsOf: priceAsOf,
            priceSource: source.rawValue,
            priceFetchedAt: priceFetchedAt,
            autoQuoteEnabled: autoQuoteEnabled,
            currencyCode: VNDCurrency.code,
            createdAt: referenceDate
        )
    }

    static func holding(
        in instrument: FundInstrument,
        units: Decimal,
        averageCostPerUnit: Decimal,
        sourceAccountID: UUID? = nil,
        createdAt: Date = referenceDate,
        id: UUID = UUID()
    ) -> FundHolding {
        FundHolding(
            id: id,
            instrumentID: instrument.id,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )
    }

    static func sale(
        of holding: FundHolding,
        units: Decimal,
        pricePerUnit: Decimal,
        proceedsAccountID: UUID = AccountSeed.unassignedID,
        soldAt: Date = referenceDate,
        id: UUID = UUID()
    ) -> FundSale {
        FundSale(
            id: id,
            holdingID: holding.id,
            units: units,
            pricePerUnit: pricePerUnit,
            proceedsAccountID: proceedsAccountID,
            soldAt: soldAt,
            currencyCode: VNDCurrency.code,
            createdAt: soldAt
        )
    }

    /// One instrument and one position in it, for the common case where a test
    /// only cares about the pair as a unit.
    static func pair(
        symbol: String = "VESAF",
        kind: FundInstrumentKind = .fund,
        units: Decimal,
        averageCostPerUnit: Decimal,
        pricePerUnit: Decimal,
        sourceAccountID: UUID? = nil
    ) -> (instrument: FundInstrument, holding: FundHolding) {
        let instrument = instrument(
            symbol: symbol,
            kind: kind,
            pricePerUnit: pricePerUnit
        )
        let holding = holding(
            in: instrument,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            sourceAccountID: sourceAccountID
        )
        return (instrument, holding)
    }
}
