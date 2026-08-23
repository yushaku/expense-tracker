import Foundation

enum FundInstrumentFormError: Error, Equatable {
    case emptySymbol
    case emptyName
    case duplicateSymbol
    case invalidPrice
    case nonPositivePrice
}

/// Validates a catalogue entry before any `FundInstrument` is written.
///
/// Ticker uniqueness is enforced here rather than with `@Attribute(.unique)`.
/// CloudKit forbids unique attributes, and the whole point of the catalogue is
/// that one ticker carries one price — a constraint the store cannot express is
/// better checked in one obvious place than assumed everywhere.
struct FundInstrumentDraft: Equatable {
    var symbol: String
    var name: String
    var kind: FundInstrumentKind
    var priceText: String
    var priceAsOf: Date
    var autoQuoteEnabled: Bool

    init(
        symbol: String = "",
        name: String = "",
        kind: FundInstrumentKind = .fund,
        priceText: String = "",
        priceAsOf: Date,
        autoQuoteEnabled: Bool = true
    ) {
        self.symbol = symbol
        self.name = name
        self.kind = kind
        self.priceText = priceText
        self.priceAsOf = priceAsOf
        self.autoQuoteEnabled = autoQuoteEnabled
    }

    init(instrument: FundInstrument) {
        self.init(
            symbol: instrument.symbol,
            name: instrument.name,
            kind: instrument.kind,
            priceText: VNDCurrency.formatPlain(instrument.currentPricePerUnit),
            priceAsOf: instrument.priceAsOf,
            autoQuoteEnabled: instrument.autoQuoteEnabled
        )
    }

    struct ValidatedValues: Equatable {
        var symbol: String
        var name: String
        var kind: FundInstrumentKind
        var currentPricePerUnit: Decimal
        var priceAsOf: Date
        var autoQuoteEnabled: Bool
    }

    /// - Parameter existing: every instrument already in the catalogue. When
    ///   editing, the instrument being edited is excluded by `editedID` so
    ///   re-saving an unchanged ticker never reports a duplicate.
    func validate(
        existing: [FundInstrument],
        editedID: UUID? = nil
    ) throws -> ValidatedValues {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else {
            throw FundInstrumentFormError.emptySymbol
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw FundInstrumentFormError.emptyName
        }

        let uppercased = trimmedSymbol.uppercased()
        let clash = existing.contains { instrument in
            instrument.id != editedID && instrument.symbol.uppercased() == uppercased
        }
        guard !clash else {
            throw FundInstrumentFormError.duplicateSymbol
        }

        guard let price = VNDCurrency.parse(priceText) else {
            throw FundInstrumentFormError.invalidPrice
        }

        guard price > 0 else {
            throw FundInstrumentFormError.nonPositivePrice
        }

        return ValidatedValues(
            symbol: uppercased,
            name: trimmedName,
            kind: kind,
            currentPricePerUnit: price,
            priceAsOf: priceAsOf,
            autoQuoteEnabled: autoQuoteEnabled
        )
    }

    func makeInstrument(
        id: UUID,
        createdAt: Date,
        existing: [FundInstrument]
    ) throws -> FundInstrument {
        let values = try validate(existing: existing)

        return FundInstrument(
            id: id,
            symbol: values.symbol,
            name: values.name,
            kind: values.kind,
            currentPricePerUnit: values.currentPricePerUnit,
            priceAsOf: values.priceAsOf,
            priceSource: FundQuoteSource.manual.rawValue,
            priceFetchedAt: nil,
            autoQuoteEnabled: values.autoQuoteEnabled,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    /// Applying a hand-edited price marks the instrument manual and forgets the
    /// fetch time. The override is a value, not a lock: a later refresh writes
    /// over it again unless automatic quotes are switched off.
    func apply(
        to instrument: FundInstrument,
        existing: [FundInstrument]
    ) throws {
        let values = try validate(existing: existing, editedID: instrument.id)

        let priceChanged =
            instrument.currentPricePerUnit != values.currentPricePerUnit
            || instrument.priceAsOf != values.priceAsOf

        instrument.symbol = values.symbol
        instrument.name = values.name
        instrument.kind = values.kind
        instrument.currentPricePerUnit = values.currentPricePerUnit
        instrument.priceAsOf = values.priceAsOf
        instrument.autoQuoteEnabled = values.autoQuoteEnabled

        if priceChanged {
            instrument.priceSource = FundQuoteSource.manual.rawValue
            instrument.priceFetchedAt = nil
        }
    }
}
