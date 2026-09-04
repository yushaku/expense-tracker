import Foundation
import Testing

@testable import MonMon

@Suite("Fund sale draft")
struct FundSaleDraftTests {
    private let soldAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDraft(
        unitsText: String = "100",
        pricePerUnitText: String = "26.000",
        feeText: String = "",
        proceedsAccountID: UUID? = UUID(),
        note: String = ""
    ) -> FundSaleDraft {
        FundSaleDraft(
            unitsText: unitsText,
            pricePerUnitText: pricePerUnitText,
            feeText: feeText,
            soldAt: soldAt,
            proceedsAccountID: proceedsAccountID,
            note: note
        )
    }

    @Test("A whole sale validates and trims its note")
    func validSaleValidates() throws {
        let accountID = UUID()
        let values = try makeDraft(proceedsAccountID: accountID, note: "  took profit  ")
            .validate(remainingUnits: 500)

        #expect(values.units == 100)
        #expect(values.pricePerUnit == 26_000)
        #expect(values.fee == 0)
        #expect(values.proceedsAccountID == accountID)
        #expect(values.soldAt == soldAt)
        #expect(values.note == "took profit")
        #expect(values.proceeds == 2_600_000)
    }

    @Test("A sale fee is optional and reduces net proceeds")
    func saleFeeReducesNetProceeds() throws {
        let values = try makeDraft(feeText: "100.000").validate(remainingUnits: 500)

        #expect(values.fee == 100_000)
        #expect(values.grossProceeds == 2_600_000)
        #expect(values.proceeds == 2_500_000)
    }

    @Test("An invalid, negative, or excessive sale fee is refused")
    func badSaleFeeIsRefused() {
        #expect(throws: FundSaleFormError.invalidFee) {
            try makeDraft(feeText: "abc").validate(remainingUnits: 500)
        }
        #expect(throws: FundSaleFormError.negativeFee) {
            try makeDraft(feeText: "-1").validate(remainingUnits: 500)
        }
        #expect(throws: FundSaleFormError.feeExceedsProceeds) {
            try makeDraft(feeText: "2.600.000").validate(remainingUnits: 500)
        }
    }

    @Test("Selling exactly what is left is allowed")
    func sellingEverythingIsAllowed() throws {
        let values = try makeDraft(unitsText: "500").validate(remainingUnits: 500)

        #expect(values.units == 500)
    }

    @Test("Selling more than is held is refused")
    func oversellingIsRefused() {
        #expect(throws: FundSaleFormError.exceedsRemainingUnits) {
            try makeDraft(unitsText: "501").validate(remainingUnits: 500)
        }
    }

    @Test("A quantity that is not a number, or is not positive, is refused")
    func badQuantityIsRefused() {
        #expect(throws: FundSaleFormError.invalidUnits) {
            try makeDraft(unitsText: "abc").validate(remainingUnits: 500)
        }

        #expect(throws: FundSaleFormError.nonPositiveUnits) {
            try makeDraft(unitsText: "0").validate(remainingUnits: 500)
        }
    }

    @Test("A price that is not a number, or is not positive, is refused")
    func badPriceIsRefused() {
        #expect(throws: FundSaleFormError.invalidPrice) {
            try makeDraft(pricePerUnitText: "abc").validate(remainingUnits: 500)
        }

        #expect(throws: FundSaleFormError.nonPositivePrice) {
            try makeDraft(pricePerUnitText: "0").validate(remainingUnits: 500)
        }
    }

    @Test("A sale with nowhere to pay is refused")
    func missingAccountIsRefused() {
        #expect(throws: FundSaleFormError.missingAccount) {
            try makeDraft(proceedsAccountID: nil).validate(remainingUnits: 500)
        }
    }

    @Test("The quantity is checked before the price, so the first fault named is the first one")
    func quantityIsCheckedFirst() {
        #expect(throws: FundSaleFormError.exceedsRemainingUnits) {
            try makeDraft(unitsText: "900", pricePerUnitText: "0")
                .validate(remainingUnits: 500)
        }
    }

    @Test("Re-saving a sale unchanged is not read as overselling")
    func editingASaleAddsItsOwnUnitsBack() throws {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sale = FundTestFactory.sale(
            of: holding,
            units: 400,
            pricePerUnit: 26_000,
            fee: 25_000
        )

        // What the editor hands the draft: what is left, plus this sale's own
        // units, because they are about to be rewritten rather than added to.
        let remaining = holding.remainingUnits(sales: [sale]) + sale.units
        #expect(remaining == 1_000)

        try FundSaleDraft(sale: sale).apply(to: sale, remainingUnits: remaining)

        #expect(sale.units == 400)
        #expect(sale.pricePerUnit == 26_000)
        #expect(sale.fee == 25_000)
    }

    @Test("Growing a sale past what is left is still refused while editing")
    func editingCannotOversell() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sale = FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)
        let remaining = holding.remainingUnits(sales: [sale]) + sale.units

        #expect(throws: FundSaleFormError.exceedsRemainingUnits) {
            try makeDraft(unitsText: "1001").apply(to: sale, remainingUnits: remaining)
        }

        #expect(sale.units == 400)
    }

    @Test("A failed sale leaves the record it was editing untouched")
    func failedApplyLeavesTheSaleAlone() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sale = FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)

        #expect(throws: FundSaleFormError.missingAccount) {
            try makeDraft(unitsText: "50", proceedsAccountID: nil)
                .apply(to: sale, remainingUnits: 1_000)
        }

        #expect(sale.units == 400)
        #expect(sale.pricePerUnit == 26_000)
    }

    @Test("Gold typed in chỉ is stored in lượng")
    func goldConvertsChiToLuong() throws {
        // What `FundSaleEditorView.draftForSaving` does before validating: five
        // chỉ is half a lượng, and the store only ever holds lượng.
        let luong = try #require(GoldWeight.parseChi("5"))
        let draft = makeDraft(
            unitsText: NSDecimalNumber(decimal: luong).stringValue,
            pricePerUnitText: "80.000.000"
        )

        let values = try draft.validate(remainingUnits: 1)

        #expect(values.units == Decimal(string: "0.5"))
        #expect(values.proceeds == 40_000_000)
    }

    @Test("A sale builds a record that names its lot and its account")
    func makeSaleCarriesEverything() throws {
        let accountID = UUID()
        let holdingID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        let sale = try makeDraft(proceedsAccountID: accountID).makeSale(
            id: UUID(),
            holdingID: holdingID,
            createdAt: createdAt,
            remainingUnits: 500
        )

        #expect(sale.holdingID == holdingID)
        #expect(sale.units == 100)
        #expect(sale.pricePerUnit == 26_000)
        #expect(sale.proceedsAccountID == accountID)
        #expect(sale.soldAt == soldAt)
        #expect(sale.createdAt == createdAt)
        #expect(sale.currencyCode == VNDCurrency.code)
    }

    // MARK: - Dollars

    private func usdSaleDraft(
        pricePerUnitText: String = "82000",
        exchangeRateText: String = "26.058"
    ) -> FundSaleDraft {
        FundSaleDraft(
            unitsText: "1",
            pricePerUnitText: pricePerUnitText,
            priceCurrency: .usd,
            exchangeRateText: exchangeRateText,
            soldAt: FundTestFactory.referenceDate,
            proceedsAccountID: AccountSeed.unassignedID
        )
    }

    @Test("A dollar sale price is converted once, on the way in")
    func dollarPriceIsConverted() throws {
        let values = try usdSaleDraft().validate(remainingUnits: 2)

        #expect(values.pricePerUnit == 2_136_756_000)
        #expect(values.exchangeRate == 26_058)
        #expect(values.proceeds == 2_136_756_000)
    }

    @Test("The rate reaches the sale and the proceeds stay in đồng")
    func rateReachesTheSale() throws {
        let sale = try usdSaleDraft().makeSale(
            id: UUID(),
            holdingID: UUID(),
            createdAt: FundTestFactory.referenceDate,
            remainingUnits: 2
        )

        #expect(sale.pricePerUnit == 2_136_756_000)
        #expect(sale.exchangeRate == 26_058)
        #expect(sale.currencyCode == VNDCurrency.code)
    }

    @Test("A dollar sale reopens in dollars, at the rate it was written with")
    func dollarSaleReopensInDollars() throws {
        let sale = try usdSaleDraft().makeSale(
            id: UUID(),
            holdingID: UUID(),
            createdAt: FundTestFactory.referenceDate,
            remainingUnits: 2
        )

        let reopened = FundSaleDraft(sale: sale)

        #expect(reopened.priceCurrency == .usd)
        #expect(reopened.pricePerUnitText == "82000")
        #expect(reopened.exchangeRateText == VNDCurrency.formatPlain(26_058))
    }

    @Test("A đồng sale carries no rate and reopens in đồng")
    func dongSaleCarriesNoRate() throws {
        let sale = try FundSaleDraft(
            unitsText: "1",
            pricePerUnitText: "30.000",
            soldAt: FundTestFactory.referenceDate,
            proceedsAccountID: AccountSeed.unassignedID
        )
        .makeSale(
            id: UUID(),
            holdingID: UUID(),
            createdAt: FundTestFactory.referenceDate,
            remainingUnits: 2
        )

        #expect(sale.exchangeRate == nil)
        #expect(FundSaleDraft(sale: sale).priceCurrency == .vnd)
        #expect(sale.pricePerUnitInDollars == nil)
    }

    @Test("A missing or nonsensical rate is rejected, and names itself")
    func badSaleRateIsRejected() {
        #expect(saleError(from: usdSaleDraft(exchangeRateText: "")) == .invalidExchangeRate)
        #expect(saleError(from: usdSaleDraft(exchangeRateText: "0")) == .nonPositiveExchangeRate)
    }

    @Test("A zero dollar price is rejected before the rate is even read")
    func zeroDollarPriceIsRejected() {
        #expect(saleError(from: usdSaleDraft(pricePerUnitText: "0")) == .nonPositivePrice)
        #expect(saleError(from: usdSaleDraft(pricePerUnitText: "")) == .invalidPrice)
    }

    private func saleError(from draft: FundSaleDraft) -> FundSaleFormError? {
        do {
            _ = try draft.validate(remainingUnits: 2)
            return nil
        } catch let error as FundSaleFormError {
            return error
        } catch {
            return nil
        }
    }
}
