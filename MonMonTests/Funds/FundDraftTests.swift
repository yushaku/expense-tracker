import Foundation
import Testing

@testable import MonMon

@Suite("Fund draft")
struct FundDraftTests {
    private let navAsOf = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDraft(
        name: String = "VinaCapital VESAF",
        symbol: String = "VESAF",
        kind: FundHoldingKind = .fund,
        unitsText: String = "1000",
        averageCostText: String = "20.000",
        navText: String = "25.000",
        sourceAccountID: UUID? = nil
    ) -> FundDraft {
        FundDraft(
            name: name,
            symbol: symbol,
            kind: kind,
            unitsText: unitsText,
            averageCostText: averageCostText,
            navText: navText,
            navAsOf: navAsOf,
            sourceAccountID: sourceAccountID
        )
    }

    @Test("A complete draft validates into exact decimal values")
    func completeDraftValidates() throws {
        let values = try makeDraft().validate(availableSourceBalance: nil)

        #expect(values.name == "VinaCapital VESAF")
        #expect(values.symbol == "VESAF")
        #expect(values.kind == .fund)
        #expect(values.units == 1_000)
        #expect(values.averageCostPerUnit == 20_000)
        #expect(values.currentNAVPerUnit == 25_000)
        #expect(values.navAsOf == navAsOf)
        #expect(values.costBasis == 20_000_000)
    }

    @Test("The name and symbol are trimmed and the symbol is uppercased")
    func nameAndSymbolAreNormalized() throws {
        let values = try makeDraft(name: "  VESAF Fund  ", symbol: " vesaf ")
            .validate(availableSourceBalance: nil)

        #expect(values.name == "VESAF Fund")
        #expect(values.symbol == "VESAF")
    }

    @Test("A blank name is rejected")
    func blankNameIsRejected() {
        #expect(throws: FundFormError.emptyName) {
            try makeDraft(name: "   ").validate(availableSourceBalance: nil)
        }
    }

    @Test("A blank symbol is rejected")
    func blankSymbolIsRejected() {
        #expect(throws: FundFormError.emptySymbol) {
            try makeDraft(symbol: "  ").validate(availableSourceBalance: nil)
        }
    }

    @Test("Unparsable units are rejected")
    func unparsableUnitsAreRejected() {
        #expect(throws: FundFormError.invalidUnits) {
            try makeDraft(unitsText: "một nghìn").validate(availableSourceBalance: nil)
        }
    }

    @Test("Zero and negative units are rejected")
    func nonPositiveUnitsAreRejected() {
        #expect(throws: FundFormError.nonPositiveUnits) {
            try makeDraft(unitsText: "0").validate(availableSourceBalance: nil)
        }
        #expect(throws: FundFormError.nonPositiveUnits) {
            try makeDraft(unitsText: "-10").validate(availableSourceBalance: nil)
        }
    }

    @Test("An unparsable average cost is rejected")
    func unparsableAverageCostIsRejected() {
        #expect(throws: FundFormError.invalidAverageCost) {
            try makeDraft(averageCostText: "").validate(availableSourceBalance: nil)
        }
    }

    @Test("A zero average cost is rejected")
    func nonPositiveAverageCostIsRejected() {
        #expect(throws: FundFormError.nonPositiveAverageCost) {
            try makeDraft(averageCostText: "0").validate(availableSourceBalance: nil)
        }
    }

    @Test("An unparsable NAV is rejected")
    func unparsableNAVIsRejected() {
        #expect(throws: FundFormError.invalidNAV) {
            try makeDraft(navText: "   ").validate(availableSourceBalance: nil)
        }
    }

    @Test("A zero NAV is rejected")
    func nonPositiveNAVIsRejected() {
        #expect(throws: FundFormError.nonPositiveNAV) {
            try makeDraft(navText: "0").validate(availableSourceBalance: nil)
        }
    }

    @Test("A cost basis above the source balance is rejected")
    func overfundingIsRejected() {
        #expect(throws: FundFormError.insufficientSourceBalance) {
            try makeDraft().validate(availableSourceBalance: 19_999_999)
        }
    }

    @Test("A cost basis exactly equal to the source balance is accepted")
    func spendingTheWholeBalanceIsAccepted() throws {
        let values = try makeDraft().validate(availableSourceBalance: 20_000_000)

        #expect(values.costBasis == 20_000_000)
    }

    @Test("The balance is checked against the cost basis, not the market value")
    func balanceIsCheckedAgainstCostBasis() throws {
        // Market value is 25.000.000 ₫ but only 20.000.000 ₫ ever left the account.
        let values = try makeDraft(navText: "25.000")
            .validate(availableSourceBalance: 20_000_000)

        #expect(values.costBasis == 20_000_000)
    }

    @Test("Re-saving an unchanged holding never reports an overdraft")
    func editingWithoutChangesIsNotAnOverdraft() throws {
        let accountID = UUID()
        let holding = try makeDraft(sourceAccountID: accountID)
            .makeHolding(
                id: UUID(),
                createdAt: navAsOf,
                availableSourceBalance: 20_000_000
            )
        let draft = FundDraft(holding: holding)

        // The caller adds the holding's own cost basis back to a now-empty balance.
        let values = try draft.validate(availableSourceBalance: holding.costBasis)

        #expect(values.costBasis == 20_000_000)
    }

    @Test("A holding round-trips through a draft unchanged")
    func holdingRoundTripsThroughDraft() throws {
        let accountID = UUID()
        let units = try #require(Decimal(string: "1234.5678"))
        let nav = try #require(Decimal(string: "27431.28"))
        let holding = FundHolding(
            id: UUID(),
            name: "VinaCapital VESAF",
            symbol: "VESAF",
            kind: .etf,
            units: units,
            averageCostPerUnit: 24_500,
            currentNAVPerUnit: nav,
            navAsOf: navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: navAsOf,
            sourceAccountID: accountID
        )

        let values = try FundDraft(holding: holding)
            .validate(availableSourceBalance: nil)

        #expect(values.name == holding.name)
        #expect(values.symbol == holding.symbol)
        #expect(values.kind == .etf)
        #expect(values.units == units)
        #expect(values.averageCostPerUnit == 24_500)
        #expect(values.currentNAVPerUnit == nav)
        #expect(values.navAsOf == navAsOf)
    }

    @Test("Making a holding stamps VND and keeps the chosen source account")
    func makeHoldingStampsCurrencyAndSource() throws {
        let accountID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_086_400)
        let holding = try makeDraft(kind: .etf, sourceAccountID: accountID)
            .makeHolding(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)

        #expect(holding.currencyCode == "VND")
        #expect(holding.createdAt == createdAt)
        #expect(holding.kind == .etf)
        #expect(holding.sourceAccountID == accountID)
        #expect(holding.marketValue == 25_000_000)
    }

    @Test("Applying a draft rewrites every editable field")
    func applyRewritesEveryField() throws {
        let holding = try makeDraft()
            .makeHolding(id: UUID(), createdAt: navAsOf, availableSourceBalance: nil)
        let accountID = UUID()
        var draft = FundDraft(holding: holding)
        draft.name = "Diamond ETF"
        draft.symbol = "fuevfvnd"
        draft.kind = .etf
        draft.unitsText = "2000"
        draft.navText = "30.000"
        draft.sourceAccountID = accountID

        try draft.apply(to: holding, availableSourceBalance: nil)

        #expect(holding.name == "Diamond ETF")
        #expect(holding.symbol == "FUEVFVND")
        #expect(holding.kind == .etf)
        #expect(holding.units == 2_000)
        #expect(holding.currentNAVPerUnit == 30_000)
        #expect(holding.sourceAccountID == accountID)
        #expect(holding.costBasis == 40_000_000)
    }
}
