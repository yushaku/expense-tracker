import Foundation
import Testing

@testable import MonMon

@Suite("Fund draft")
struct FundDraftTests {
    private let createdAt = FundTestFactory.referenceDate
    private let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)

    private func makeDraft(
        instrumentID: UUID?,
        unitsText: String = "1000",
        averageCostText: String = "20.000",
        sourceAccountID: UUID? = nil
    ) -> FundDraft {
        FundDraft(
            instrumentID: instrumentID,
            unitsText: unitsText,
            averageCostText: averageCostText,
            sourceAccountID: sourceAccountID
        )
    }

    /// The day the units were bought is the owner's, not the app's: a DCA stack
    /// is usually typed in weeks after the purchases it records.
    @Test("A new draft defaults to today and carries the chosen day onto the holding")
    func purchaseDayIsCarried() throws {
        let lastMonth = createdAt.addingTimeInterval(-30 * 86_400)
        var draft = makeDraft(instrumentID: instrument.id)

        #expect(abs(draft.purchasedAt.timeIntervalSinceNow) < 5)

        draft.purchasedAt = lastMonth
        let holding = try draft.makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(holding.purchasedAt == lastMonth)
        #expect(holding.boughtOn == lastMonth)
        // Entered now, bought then: the two dates are allowed to disagree.
        #expect(holding.createdAt == createdAt)
    }

    @Test("Editing moves the purchase day and a record without one reads as entered")
    func purchaseDayIsEditable() throws {
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            createdAt: createdAt
        )

        // Written before the app asked for a purchase day.
        #expect(holding.purchasedAt == nil)
        #expect(holding.boughtOn == createdAt)

        var draft = FundDraft(holding: holding)
        #expect(draft.purchasedAt == createdAt)

        let earlier = createdAt.addingTimeInterval(-7 * 86_400)
        draft.purchasedAt = earlier
        try draft.apply(to: holding, availableSourceBalance: nil)

        #expect(holding.boughtOn == earlier)
    }

    @Test("A complete draft validates into exact decimal values")
    func completeDraftValidates() throws {
        let values = try makeDraft(instrumentID: instrument.id)
            .validate(availableSourceBalance: nil)

        #expect(values.instrumentID == instrument.id)
        #expect(values.units == 1_000)
        #expect(values.averageCostPerUnit == 20_000)
        #expect(values.costBasis == 20_000_000)
    }

    /// A position with no instrument has no ticker, no price, and no way to be
    /// valued — the same reasoning that makes a transaction's account required.
    @Test("A draft with no instrument is rejected")
    func missingInstrumentIsRejected() {
        #expect(throws: FundFormError.missingInstrument) {
            try makeDraft(instrumentID: nil).validate(availableSourceBalance: nil)
        }
    }

    @Test("Unparsable units are rejected")
    func unparsableUnitsAreRejected() {
        #expect(throws: FundFormError.invalidUnits) {
            try makeDraft(instrumentID: instrument.id, unitsText: "một nghìn")
                .validate(availableSourceBalance: nil)
        }
    }

    @Test("Zero and negative units are rejected")
    func nonPositiveUnitsAreRejected() {
        #expect(throws: FundFormError.nonPositiveUnits) {
            try makeDraft(instrumentID: instrument.id, unitsText: "0")
                .validate(availableSourceBalance: nil)
        }
        #expect(throws: FundFormError.nonPositiveUnits) {
            try makeDraft(instrumentID: instrument.id, unitsText: "-10")
                .validate(availableSourceBalance: nil)
        }
    }

    @Test("An unparsable average cost is rejected")
    func unparsableAverageCostIsRejected() {
        #expect(throws: FundFormError.invalidAverageCost) {
            try makeDraft(instrumentID: instrument.id, averageCostText: "")
                .validate(availableSourceBalance: nil)
        }
    }

    @Test("A zero average cost is rejected")
    func nonPositiveAverageCostIsRejected() {
        #expect(throws: FundFormError.nonPositiveAverageCost) {
            try makeDraft(instrumentID: instrument.id, averageCostText: "0")
                .validate(availableSourceBalance: nil)
        }
    }

    @Test("A cost basis above the source balance is rejected")
    func overfundingIsRejected() {
        #expect(throws: FundFormError.insufficientSourceBalance) {
            try makeDraft(instrumentID: instrument.id)
                .validate(availableSourceBalance: 19_999_999)
        }
    }

    @Test("A cost basis exactly equal to the source balance is accepted")
    func spendingTheWholeBalanceIsAccepted() throws {
        let values = try makeDraft(instrumentID: instrument.id)
            .validate(availableSourceBalance: 20_000_000)

        #expect(values.costBasis == 20_000_000)
    }

    /// The balance test cannot see a price at all now, which is the point: only
    /// cost basis ever left the funding account.
    @Test("The balance is checked against the cost basis, not the market value")
    func balanceIsCheckedAgainstCostBasis() throws {
        let expensive = FundTestFactory.instrument(pricePerUnit: 999_000)
        let values = try makeDraft(instrumentID: expensive.id)
            .validate(availableSourceBalance: 20_000_000)

        #expect(values.costBasis == 20_000_000)
    }

    @Test("Re-saving an unchanged holding never reports an overdraft")
    func editingWithoutChangesIsNotAnOverdraft() throws {
        let accountID = UUID()
        let holding = try makeDraft(instrumentID: instrument.id, sourceAccountID: accountID)
            .makeHolding(
                id: UUID(),
                createdAt: createdAt,
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
        let holding = FundTestFactory.holding(
            in: instrument,
            units: units,
            averageCostPerUnit: 24_500,
            sourceAccountID: accountID
        )

        let values = try FundDraft(holding: holding).validate(availableSourceBalance: nil)

        #expect(values.instrumentID == instrument.id)
        #expect(values.units == units)
        #expect(values.averageCostPerUnit == 24_500)
    }

    @Test("Making a holding keeps the instrument and the chosen source account")
    func makeHoldingKeepsInstrumentAndSource() throws {
        let accountID = UUID()
        let stamped = Date(timeIntervalSince1970: 1_700_086_400)
        let holding = try makeDraft(instrumentID: instrument.id, sourceAccountID: accountID)
            .makeHolding(id: UUID(), createdAt: stamped, availableSourceBalance: nil)

        #expect(holding.instrumentID == instrument.id)
        #expect(holding.createdAt == stamped)
        #expect(holding.sourceAccountID == accountID)
        #expect(holding.marketValue(in: [instrument], sales: []) == 25_000_000)
    }

    @Test("Applying a draft rewrites every editable field")
    func applyRewritesEveryField() throws {
        let holding = try makeDraft(instrumentID: instrument.id)
            .makeHolding(id: UUID(), createdAt: createdAt, availableSourceBalance: nil)
        let other = FundTestFactory.instrument(symbol: "FUEVFVND", pricePerUnit: 30_000)
        let accountID = UUID()

        try makeDraft(
            instrumentID: other.id,
            unitsText: "250",
            averageCostText: "32.100",
            sourceAccountID: accountID
        )
        .apply(to: holding, availableSourceBalance: nil)

        #expect(holding.instrumentID == other.id)
        #expect(holding.units == 250)
        #expect(holding.averageCostPerUnit == 32_100)
        #expect(holding.sourceAccountID == accountID)
    }

    /// Moving a position to another instrument re-prices it, which is only
    /// correct because the price was never copied onto the holding.
    @Test("Re-pointing a holding values it at the new instrument's price")
    func repointingRevaluesTheHolding() throws {
        let cheap = FundTestFactory.instrument(symbol: "AAA", pricePerUnit: 10_000)
        let dear = FundTestFactory.instrument(symbol: "BBB", pricePerUnit: 40_000)
        let holding = FundTestFactory.holding(
            in: cheap,
            units: 100,
            averageCostPerUnit: 10_000
        )

        #expect(holding.marketValue(in: [cheap, dear], sales: []) == 1_000_000)

        holding.instrumentID = dear.id

        #expect(holding.marketValue(in: [cheap, dear], sales: []) == 4_000_000)
        #expect(holding.costBasis == 1_000_000)
    }

    // MARK: - Dollars

    private func usdDraft(
        averageCostText: String = "79463",
        exchangeRateText: String = "26.058"
    ) -> FundDraft {
        FundDraft(
            instrumentID: instrument.id,
            unitsText: "2",
            averageCostText: averageCostText,
            costCurrency: .usd,
            exchangeRateText: exchangeRateText
        )
    }

    @Test("A dollar cost is converted once, on the way in")
    func dollarCostIsConverted() throws {
        let values = try usdDraft().validate(availableSourceBalance: nil)

        #expect(values.averageCostPerUnit == 2_070_646_854)
        #expect(values.exchangeRate == 26_058)
    }

    /// The rate is kept so the editor can reopen in dollars, but what every
    /// total settles against is still the đồng figure.
    @Test("The rate reaches the holding and the cost stays in đồng")
    func rateReachesTheHolding() throws {
        let holding = try usdDraft().makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(holding.averageCostPerUnit == 2_070_646_854)
        #expect(holding.purchaseExchangeRate == 26_058)
        #expect(holding.costBasis == 4_141_293_708)
    }

    @Test("A đồng cost carries no rate at all")
    func dongCostCarriesNoRate() throws {
        let holding = try makeDraft(instrumentID: instrument.id).makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(holding.purchaseExchangeRate == nil)
        #expect(holding.averageCostPerUnitInDollars == nil)
    }

    @Test("A dollar position reopens in dollars, at the rate it was written with")
    func dollarPositionReopensInDollars() throws {
        let holding = try usdDraft().makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        let reopened = FundDraft(holding: holding)

        #expect(reopened.costCurrency == .usd)
        #expect(reopened.averageCostText == "79463")
        #expect(reopened.exchangeRateText == VNDCurrency.formatPlain(26_058))
    }

    @Test("A đồng position reopens in đồng")
    func dongPositionReopensInDong() throws {
        let holding = try makeDraft(instrumentID: instrument.id).makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        #expect(FundDraft(holding: holding).costCurrency == .vnd)
    }

    /// Retyping the cost in đồng has to drop the rate, or the position would
    /// keep a number that no longer explains what it cost.
    @Test("Switching back to đồng clears the stored rate")
    func switchingBackClearsTheRate() throws {
        let holding = try usdDraft().makeHolding(
            id: UUID(),
            createdAt: createdAt,
            availableSourceBalance: nil
        )

        try makeDraft(instrumentID: instrument.id)
            .apply(to: holding, availableSourceBalance: nil)

        #expect(holding.purchaseExchangeRate == nil)
        #expect(holding.averageCostPerUnit == 20_000)
    }

    @Test("A missing or nonsensical rate is rejected, and names itself")
    func badRateIsRejected() {
        #expect(
            error(from: usdDraft(exchangeRateText: "")) == .invalidExchangeRate
        )
        #expect(
            error(from: usdDraft(exchangeRateText: "twenty")) == .invalidExchangeRate
        )
        #expect(
            error(from: usdDraft(exchangeRateText: "0")) == .nonPositiveExchangeRate
        )
    }

    @Test("A zero dollar cost is rejected before the rate is even read")
    func zeroDollarCostIsRejected() {
        #expect(error(from: usdDraft(averageCostText: "0")) == .nonPositiveAverageCost)
        #expect(error(from: usdDraft(averageCostText: "")) == .invalidAverageCost)
    }

    /// A coin worth a fraction of a đồng still has a cost. Rounding the
    /// converted figure would store zero and fail validation.
    @Test("A sub-đồng dollar price survives conversion")
    func subDongDollarPriceSurvives() throws {
        let values = try usdDraft(averageCostText: "0,000001")
            .validate(availableSourceBalance: nil)

        #expect(values.averageCostPerUnit > 0)
    }

    private func error(from draft: FundDraft) -> FundFormError? {
        do {
            _ = try draft.validate(availableSourceBalance: nil)
            return nil
        } catch let error as FundFormError {
            return error
        } catch {
            return nil
        }
    }
}
