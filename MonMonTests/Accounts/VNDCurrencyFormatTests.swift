import Foundation
import Testing

@testable import MonMon

@Suite("VND compact formatting")
struct VNDCurrencyFormatTests {
    @Test("Amounts below a thousand keep whole đồng")
    func smallAmountsKeepDong() {
        #expect(VNDCurrency.format(Decimal(0)) == "0đ")
        #expect(VNDCurrency.format(Decimal(1)) == "1đ")
        #expect(VNDCurrency.format(Decimal(10)) == "10đ")
        #expect(VNDCurrency.format(Decimal(100)) == "100đ")
        #expect(VNDCurrency.format(Decimal(999)) == "999đ")
    }

    @Test("Thousands abbreviate to k with at most one decimal")
    func thousandsAbbreviate() {
        #expect(VNDCurrency.format(Decimal(1_000)) == "1k")
        #expect(VNDCurrency.format(Decimal(1_234)) == "1,2k")
        #expect(VNDCurrency.format(Decimal(1_500)) == "1,5k")
        #expect(VNDCurrency.format(Decimal(850_000)) == "850k")
    }

    @Test("Millions and billions abbreviate to M and B")
    func millionsAndBillionsAbbreviate() {
        #expect(VNDCurrency.format(Decimal(1_234_567)) == "1,2M")
        #expect(VNDCurrency.format(Decimal(2_000_000)) == "2M")
        #expect(VNDCurrency.format(Decimal(45_600_000)) == "45,6M")
        #expect(VNDCurrency.format(Decimal(1_000_000_000)) == "1B")
        #expect(VNDCurrency.format(Decimal(2_500_000_000)) == "2,5B")
    }

    @Test("Rounding onto the next tier promotes the suffix")
    func roundingPromotesTheTier() {
        #expect(VNDCurrency.format(Decimal(9_996) / Decimal(10)) == "1k")
        #expect(VNDCurrency.format(Decimal(999_960)) == "1M")
        #expect(VNDCurrency.format(Decimal(999_999_960)) == "1B")
    }

    @Test("Negative amounts keep a leading minus")
    func negativeAmountsKeepTheirSign() {
        #expect(VNDCurrency.format(Decimal(-500)) == "-500đ")
        #expect(VNDCurrency.format(Decimal(-1_234_567)) == "-1,2M")
    }

    @Test("The Double overload matches the Decimal one")
    func doubleOverloadMatches() {
        #expect(VNDCurrency.format(1_234_567.0) == "1,2M")
        #expect(VNDCurrency.format(0.0) == "0đ")
    }

    @Test("Editable amounts still round-trip through the parser")
    func plainFormattingStillRoundTrips() {
        let amount = Decimal(1_234_567)
        let text = VNDCurrency.formatPlain(amount)

        #expect(text == "1.234.567")
        #expect(VNDCurrency.parse(text) == amount)
    }
}
