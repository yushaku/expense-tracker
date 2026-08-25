import Foundation
import Testing

@testable import MonMon

@Suite("Fund sale draft")
struct FundSaleDraftTests {
    private let soldAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDraft(
        unitsText: String = "100",
        pricePerUnitText: String = "26.000",
        proceedsAccountID: UUID? = UUID(),
        note: String = ""
    ) -> FundSaleDraft {
        FundSaleDraft(
            unitsText: unitsText,
            pricePerUnitText: pricePerUnitText,
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
        #expect(values.proceedsAccountID == accountID)
        #expect(values.soldAt == soldAt)
        #expect(values.note == "took profit")
        #expect(values.proceeds == 2_600_000)
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
        let sale = FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)

        // What the editor hands the draft: what is left, plus this sale's own
        // units, because they are about to be rewritten rather than added to.
        let remaining = holding.remainingUnits(sales: [sale]) + sale.units
        #expect(remaining == 1_000)

        try FundSaleDraft(sale: sale).apply(to: sale, remainingUnits: remaining)

        #expect(sale.units == 400)
        #expect(sale.pricePerUnit == 26_000)
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
}
