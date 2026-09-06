import Foundation
import Testing

@testable import MonMon

@Suite("Unit quantity")
struct UnitQuantityTests {
    @Test("A Vietnamese decimal comma parses")
    func decimalCommaParses() {
        #expect(UnitQuantity.parse("1234,56") == Decimal(string: "1234.56"))
    }

    @Test("A decimal dot parses the same way")
    func decimalDotParses() {
        #expect(UnitQuantity.parse("1234.56") == Decimal(string: "1234.56"))
    }

    @Test("Whole numbers and surrounding whitespace parse")
    func wholeNumbersParse() {
        #expect(UnitQuantity.parse(" 2000 ") == 2_000)
    }

    @Test("Empty and nonnumeric text is rejected")
    func invalidTextIsRejected() {
        #expect(UnitQuantity.parse("") == nil)
        #expect(UnitQuantity.parse("   ") == nil)
        #expect(UnitQuantity.parse("một nghìn") == nil)
        #expect(UnitQuantity.parse("1234,56 units") == nil)
        #expect(UnitQuantity.parse("1,2,3") == nil)
        #expect(UnitQuantity.parse("12 34") == nil)
    }

    @Test("Grouped digits are rejected so a stray separator is never a silent zero")
    func groupedDigitsAreRejected() {
        #expect(UnitQuantity.parse("1.234,56") == nil)
    }

    @Test("Negative units parse so validation can reject them by sign")
    func negativeUnitsParse() {
        #expect(UnitQuantity.parse("-1") == -1)
    }

    @Test("Formatting drops trailing zeros and keeps the fraction digits typed")
    func formattingIsCompact() {
        #expect(UnitQuantity.format(2_000) == "2000")
        #expect(UnitQuantity.format(Decimal(string: "1234.5678") ?? 0) == "1234,5678")
    }

    /// A coin is divisible to eight places, so a satoshi-scale holding has to
    /// survive being formatted and read back.
    @Test("Eight fraction digits survive formatting")
    func eightFractionDigitsAreKept() {
        #expect(UnitQuantity.format(Decimal(string: "0.12345678") ?? 0) == "0,12345678")
    }

    @Test("A formatted quantity parses back to the same value")
    func formatAndParseRoundTrip() throws {
        let units = try #require(Decimal(string: "1234.5678"))

        #expect(UnitQuantity.parse(UnitQuantity.format(units)) == units)
    }

    @Test("A satoshi-scale quantity round-trips intact")
    func satoshiRoundTrip() throws {
        let units = try #require(Decimal(string: "0.00000001"))

        #expect(UnitQuantity.parse(UnitQuantity.format(units)) == units)
    }
}
