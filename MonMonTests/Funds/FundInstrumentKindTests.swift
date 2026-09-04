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
}
