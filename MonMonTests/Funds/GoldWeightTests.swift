import Foundation
import Testing

@testable import MonMon

@Suite("Gold weight")
struct GoldWeightTests {
    @Test("Ten chỉ make one lượng")
    func chiConvertToLuong() {
        #expect(GoldWeight.chiPerLuong == 10)
        #expect(GoldWeight.parseChi("10") == 1)
        #expect(GoldWeight.formatChi(luong: 1) == "10")
    }

    @Test("Comma and dot input convert to the same stored lượng")
    func commaAndDotParseTheSame() {
        #expect(GoldWeight.parseChi("5,5") == Decimal(string: "0.55"))
        #expect(GoldWeight.parseChi("5.5") == Decimal(string: "0.55"))
    }

    @Test("Formatted chỉ round-trips through canonical lượng")
    func formatAndParseRoundTrip() throws {
        let luong = try #require(Decimal(string: "0.1234"))

        #expect(GoldWeight.parseChi(GoldWeight.formatChi(luong: luong)) == luong)
    }

    @Test("The label renders both units")
    func labelRendersBothUnits() {
        #expect(GoldWeight.label(luong: Decimal(string: "0.55") ?? 0) == "5,5 chỉ (0,55 lượng)")
    }

    @Test("Zero and negative input keep their sign for draft validation")
    func nonPositiveInputConvertsExactly() {
        #expect(GoldWeight.parseChi("0") == .zero)
        #expect(GoldWeight.parseChi("-5") == Decimal(string: "-0.5"))
    }

    @Test("Invalid input remains invalid")
    func invalidInputIsRejected() {
        #expect(GoldWeight.parseChi("") == nil)
        #expect(GoldWeight.parseChi("năm chỉ") == nil)
    }

    // MARK: - The unit a form types in

    /// Chỉ is the default because it is the amount gold is actually bought in.
    @Test("Chỉ is the default unit")
    func chiIsTheDefault() {
        #expect(FundDraft().goldUnit == .chi)
        #expect(FundSaleDraft(soldAt: FundTestFactory.referenceDate).goldUnit == .chi)
    }

    @Test("Ten chỉ make one stored lượng")
    func factorsAreTenAndOne() {
        #expect(GoldUnit.chi.perLuong == GoldWeight.chiPerLuong)
        #expect(GoldUnit.luong.perLuong == 1)
    }

    /// The point of the choice: a purchase typed in either unit has to save as
    /// exactly the same position. Weight divides by the factor, price
    /// multiplies by it, so the total is untouched.
    @Test("The same purchase in either unit costs the same")
    func eitherUnitStoresTheSamePurchase() {
        for unit in GoldUnit.allCases {
            // Two chỉ, which is a fifth of a lượng.
            let typedWeight = Decimal(2) / GoldUnit.chi.perLuong * unit.perLuong
            let typedPrice = Decimal(150_000_000) / unit.perLuong

            let storedUnits = typedWeight / unit.perLuong
            let storedPrice = typedPrice * unit.perLuong

            #expect(storedUnits == Decimal(string: "0.2"))
            #expect(storedPrice == 150_000_000)
            #expect(
                FundValuation.costBasis(
                    units: storedUnits,
                    averageCostPerUnit: storedPrice
                ) == 30_000_000
            )
        }
    }

    /// What the owner sees in either unit describes one purchase, so the
    /// product of the two boxes is the same number either way.
    @Test("The boxes multiply to the same total in either unit")
    func bothBoxesAgreeOnTheTotal() {
        let inChi = FundValuation.costBasis(units: 2, averageCostPerUnit: 15_000_000)
        let inLuong = FundValuation.costBasis(
            units: Decimal(string: "0.2") ?? 0,
            averageCostPerUnit: 150_000_000
        )

        #expect(inChi == 30_000_000)
        #expect(inChi == inLuong)
    }

    @Test("Each unit names itself")
    func unitsAreNamed() {
        #expect(GoldUnit.chi.displayNameKey == "chỉ")
        #expect(GoldUnit.luong.displayNameKey == "lượng")
    }
}
