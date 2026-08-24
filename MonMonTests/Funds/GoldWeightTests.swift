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
}
