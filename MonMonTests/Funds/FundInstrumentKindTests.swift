import Foundation
import Testing

@testable import MonMon

@Suite("Fund instrument kind")
struct FundInstrumentKindTests {
    /// The regression this exists for: the holding editor used to decide its
    /// catalogue with `kind == .gold ? [.gold] : [.fund, .etf]`, so opening a
    /// coin position offered funds and ETFs. The coin it was actually held in
    /// was not in the list, and the position could not be saved.
    @Test("A coin's editor offers coins, not funds")
    func cryptoOffersCoins() {
        #expect(FundInstrumentKind.crypto.editorKinds == [.crypto])
    }

    @Test("Gold keeps its own editor")
    func goldOffersGold() {
        #expect(FundInstrumentKind.gold.editorKinds == [.gold])
    }

    /// Funds and ETFs are the same shape of thing — units bought through a
    /// broker — so a position in one may be repointed at the other.
    @Test("Funds and ETFs share one editor")
    func fundsAndETFsShareAnEditor() {
        #expect(FundInstrumentKind.fund.editorKinds == [.fund, .etf])
        #expect(FundInstrumentKind.etf.editorKinds == [.fund, .etf])
    }

    /// Every kind has to reach an editor that contains it, or a position in it
    /// cannot be edited at all. A kind added later fails here rather than in
    /// somebody's hands.
    @Test("Every kind can be picked in its own editor")
    func everyKindIsSelectableInItsOwnEditor() {
        for kind in FundInstrumentKind.allCases {
            #expect(kind.editorKinds.contains(kind), "\(kind) cannot be picked in its own editor")
        }
    }

    @Test("Every kind names itself and its price")
    func everyKindHasCopy() {
        for kind in FundInstrumentKind.allCases {
            #expect(!kind.displayNameKey.isEmpty)
            #expect(!kind.priceLabelKey.isEmpty)
        }
    }

    @Test("Sale behavior is declared by asset policy")
    func saleBehaviorComesFromPolicy() {
        #expect(FundInstrumentKind.fund.policy.quantity == .units)
        #expect(FundInstrumentKind.etf.policy.quantity == .units)
        #expect(FundInstrumentKind.gold.policy.quantity == .goldWeight)
        #expect(FundInstrumentKind.crypto.policy.quantity == .units)

        #expect(FundInstrumentKind.gold.policy.fee == .shopDeduction)
        #expect(FundInstrumentKind.fund.policy.fee == nil)
        #expect(FundInstrumentKind.crypto.policy.allowsDollarPriceEntry)
        #expect(!FundInstrumentKind.gold.policy.allowsDollarPriceEntry)
        #expect(FundInstrumentKind.crypto.policy.supportsSwap)
        #expect(!FundInstrumentKind.gold.policy.supportsSwap)
    }

    @Test("Quantity policy owns display and storage conversion")
    func quantityPolicyConvertsAtTheBoundary() {
        let gold = FundInstrumentKind.gold.policy.quantity
        #expect(gold.displayedUnits(fromStored: 1) == 10)
        #expect(gold.storedUnits(fromDisplayed: 10) == 1)
        #expect(gold.storedUnits(fromEntryText: "5") == Decimal(string: "0.5"))

        let units = FundInstrumentKind.fund.policy.quantity
        #expect(units.displayedUnits(fromStored: 3) == 3)
        #expect(units.storedUnits(fromDisplayed: 3) == 3)
        #expect(units.storedUnits(fromEntryText: "3.5") == Decimal(string: "3.5"))
    }

    @Test("Holding editor behavior is declared by asset policy")
    func holdingEditorBehaviorComesFromPolicy() {
        #expect(FundInstrumentKind.fund.policy.editor.catalogueRoute == .instrumentEditor)
        #expect(FundInstrumentKind.etf.policy.editor.catalogueRoute == .instrumentEditor)
        #expect(FundInstrumentKind.gold.policy.editor.catalogueRoute == .goldCatalogue)
        #expect(FundInstrumentKind.crypto.policy.editor.catalogueRoute == .cryptoCatalogue)

        #expect(FundInstrumentKind.gold.policy.editor.newTitleKey == "Add gold")
        #expect(FundInstrumentKind.crypto.policy.editor.newTitleKey == "Add coin")
        #expect(FundInstrumentKind.fund.policy.editor.newTitleKey == "Add holding")
    }

    // MARK: - What a unit costs to buy

    /// A fund, an ETF and a coin are bought and valued at one published figure,
    /// so today's price is both what it is worth and what it would cost.
    @Test("A single-sided quote is its own buy price")
    func singleSidedQuoteIsItsOwnBuyPrice() {
        for kind in [FundInstrumentKind.fund, .etf, .crypto] {
            let instrument = FundTestFactory.instrument(kind: kind, pricePerUnit: 25_000)

            #expect(instrument.purchasePricePerUnit == 25_000)
        }
    }

    /// Gold is the case this exists for. `currentPricePerUnit` is the shop's
    /// buy-back side — what the owner would receive — so prefilling a cost
    /// basis with it would understate every purchase by the spread and hide the
    /// loss that buying gold genuinely opens with.
    @Test("Gold is bought at the shop's asking price, not its buy-back price")
    func goldIsBoughtAtTheAsk() {
        let gold = FundTestFactory.instrument(
            symbol: "SJL1L10",
            kind: .gold,
            pricePerUnit: 147_000_000
        )
        gold.askPricePerUnit = 150_000_000

        #expect(gold.purchasePricePerUnit == 150_000_000)
        #expect(gold.currentPricePerUnit == 147_000_000)
    }

    @Test("Gold without a two-sided quote falls back to the price it has")
    func goldWithoutASpreadFallsBack() {
        let gold = FundTestFactory.instrument(
            symbol: "SJL1L10",
            kind: .gold,
            pricePerUnit: 147_000_000
        )

        #expect(gold.askPricePerUnit == .zero)
        #expect(gold.purchasePricePerUnit == 147_000_000)
    }
}
