import Foundation
import Testing

@testable import MonMon

@Suite("Fund instrument draft")
struct FundInstrumentDraftTests {
    private let priceAsOf = FundTestFactory.referenceDate

    private func makeDraft(
        symbol: String = "VESAF",
        name: String = "VinaCapital VESAF",
        kind: FundInstrumentKind = .fund,
        priceText: String = "25.000",
        autoQuoteEnabled: Bool = true
    ) -> FundInstrumentDraft {
        FundInstrumentDraft(
            symbol: symbol,
            name: name,
            kind: kind,
            priceText: priceText,
            priceAsOf: priceAsOf,
            autoQuoteEnabled: autoQuoteEnabled
        )
    }

    @Test("A complete draft validates into exact decimal values")
    func completeDraftValidates() throws {
        let values = try makeDraft().validate(existing: [])

        #expect(values.symbol == "VESAF")
        #expect(values.name == "VinaCapital VESAF")
        #expect(values.kind == .fund)
        #expect(values.currentPricePerUnit == 25_000)
        #expect(values.priceAsOf == priceAsOf)
        #expect(values.autoQuoteEnabled)
    }

    @Test("Appending a digit to a grouped price preserves every digit")
    func appendingDigitToGroupedPricePreservesEveryDigit() throws {
        let values = try makeDraft(priceText: "1.000.0000").validate(existing: [])

        #expect(values.currentPricePerUnit == 10_000_000)
    }

    @Test("Price input groups thousands while preserving typed decimal digits")
    func priceInputGroupsThousandsWhilePreservingDecimalDigits() {
        #expect(VNDCurrency.formatInput("1000000,500") == "1.000.000,500")
    }

    @Test("Price input groups whole amounts while digits are entered")
    func priceInputGroupsWholeAmounts() {
        #expect(VNDCurrency.formatInput("1000") == "1.000")
        #expect(VNDCurrency.formatInput("1000000") == "1.000.000")
    }

    @Test("The symbol is trimmed and uppercased, and the name is trimmed")
    func symbolAndNameAreNormalized() throws {
        let values = try makeDraft(symbol: " vesaf ", name: "  VESAF Fund  ")
            .validate(existing: [])

        #expect(values.symbol == "VESAF")
        #expect(values.name == "VESAF Fund")
    }

    @Test("A blank symbol is rejected")
    func blankSymbolIsRejected() {
        #expect(throws: FundInstrumentFormError.emptySymbol) {
            try makeDraft(symbol: "   ").validate(existing: [])
        }
    }

    @Test("A blank name is rejected")
    func blankNameIsRejected() {
        #expect(throws: FundInstrumentFormError.emptyName) {
            try makeDraft(name: "  ").validate(existing: [])
        }
    }

    /// The constraint the store cannot express, so it lives here: one ticker,
    /// one row, one price.
    @Test("A duplicate ticker is rejected, compared case-insensitively")
    func duplicateSymbolIsRejected() {
        let existing = [FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)]

        #expect(throws: FundInstrumentFormError.duplicateSymbol) {
            try makeDraft(symbol: "vesaf").validate(existing: existing)
        }
        #expect(throws: FundInstrumentFormError.duplicateSymbol) {
            try makeDraft(symbol: " VESAF ").validate(existing: existing)
        }
    }

    @Test("Another ticker alongside an existing one is accepted")
    func differentSymbolIsAccepted() throws {
        let existing = [FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)]
        let values = try makeDraft(symbol: "FUEVFVND").validate(existing: existing)

        #expect(values.symbol == "FUEVFVND")
    }

    @Test("Re-saving an instrument under its own ticker is not a duplicate")
    func editingKeepsItsOwnSymbol() throws {
        let instrument = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)
        let values = try makeDraft(symbol: "VESAF")
            .validate(existing: [instrument], editedID: instrument.id)

        #expect(values.symbol == "VESAF")
    }

    @Test("An unparsable price is rejected")
    func unparsablePriceIsRejected() {
        #expect(throws: FundInstrumentFormError.invalidPrice) {
            try makeDraft(priceText: "  ").validate(existing: [])
        }
    }

    @Test("Zero and negative prices are rejected")
    func nonPositivePriceIsRejected() {
        #expect(throws: FundInstrumentFormError.nonPositivePrice) {
            try makeDraft(priceText: "0").validate(existing: [])
        }
    }

    @Test("A new instrument is stamped manual, VND, and never pre-fetched")
    func makeInstrumentStampsItsOrigin() throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_086_400)
        let instrument = try makeDraft(kind: .etf)
            .makeInstrument(id: UUID(), createdAt: createdAt, existing: [])

        #expect(instrument.kind == .etf)
        #expect(instrument.currencyCode == "VND")
        #expect(instrument.createdAt == createdAt)
        #expect(instrument.source == .manual)
        #expect(instrument.priceFetchedAt == nil)
        #expect(instrument.askPricePerUnit == .zero)
    }

    @Test("Gold is offered as an instrument kind with its shop-buy price label")
    func goldKindIsDescribed() {
        #expect(FundInstrumentKind.gold.displayName == "Gold")
        #expect(FundInstrumentKind.gold.priceLabel == "Shop buy price per lượng")
        #expect(FundQuoteSource.vangToday.displayName == "vang.today")
    }

    @Test("Instrument list scopes keep funds and gold separate")
    func instrumentListScopesSeparateKinds() {
        #expect(FundInstrumentListScope.funds.kinds == [.fund, .etf])
        #expect(FundInstrumentListScope.funds.defaultKind == .fund)
        #expect(FundInstrumentListScope.funds.importOptions.map(\.source) == [.fmarket, .vndirect])

        #expect(FundInstrumentListScope.gold.kinds == [.gold])
        #expect(FundInstrumentListScope.gold.defaultKind == .gold)
        #expect(FundInstrumentListScope.gold.importOptions.map(\.source) == [.vangToday])
    }

    @Test("The combined instrument list continues to include every kind")
    func combinedInstrumentListIncludesEveryKind() {
        #expect(FundInstrumentListScope.all.kinds == FundInstrumentKind.allCases)
    }

    @Test("An instrument round-trips through a draft unchanged")
    func instrumentRoundTripsThroughDraft() throws {
        let instrument = FundTestFactory.instrument(
            symbol: "FUEVFVND",
            name: "Diamond ETF",
            kind: .etf,
            pricePerUnit: 29_850,
            autoQuoteEnabled: false
        )

        let values = try FundInstrumentDraft(instrument: instrument)
            .validate(existing: [instrument], editedID: instrument.id)

        #expect(values.symbol == "FUEVFVND")
        #expect(values.name == "Diamond ETF")
        #expect(values.kind == .etf)
        #expect(values.currentPricePerUnit == 29_850)
        #expect(values.autoQuoteEnabled == false)
    }

    /// Typing over a fetched price hands ownership back to the owner, so the row
    /// stops claiming a provider stands behind a figure it did not supply.
    @Test("Editing the price marks the instrument manual and forgets the fetch")
    func editingThePriceMarksItManual() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_086_400)
        let instrument = FundTestFactory.instrument(
            pricePerUnit: 25_000,
            source: .fmarket,
            priceFetchedAt: fetchedAt
        )

        try makeDraft(priceText: "31.000").apply(to: instrument, existing: [instrument])

        #expect(instrument.currentPricePerUnit == 31_000)
        #expect(instrument.source == .manual)
        #expect(instrument.priceFetchedAt == nil)
    }

    @Test("Changing the kind clears the old provider and any gold ask")
    func changingKindClearsProviderState() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_086_400)
        let instrument = FundTestFactory.instrument(
            symbol: "SJL1L10",
            name: "SJC 9999",
            kind: .gold,
            pricePerUnit: 147_000_000,
            source: .vangToday,
            priceFetchedAt: fetchedAt
        )
        instrument.askPricePerUnit = 150_000_000

        try makeDraft(
            symbol: "SJL1L10",
            name: "SJC 9999",
            kind: .fund,
            priceText: "147.000.000"
        )
        .apply(to: instrument, existing: [instrument])

        #expect(instrument.kind == .fund)
        #expect(instrument.askPricePerUnit == .zero)
        #expect(instrument.source == .manual)
        #expect(instrument.priceFetchedAt == nil)
    }

    @Test("Editing only the name leaves a fetched price attributed to its source")
    func editingTheNameKeepsTheSource() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_086_400)
        let instrument = FundTestFactory.instrument(
            pricePerUnit: 25_000,
            source: .fmarket,
            priceFetchedAt: fetchedAt
        )

        try makeDraft(name: "Renamed", priceText: "25.000")
            .apply(to: instrument, existing: [instrument])

        #expect(instrument.name == "Renamed")
        #expect(instrument.source == .fmarket)
        #expect(instrument.priceFetchedAt == fetchedAt)
    }
}
