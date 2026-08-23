import Foundation
import Testing

@testable import MonMon

@Suite("Percent input")
struct PercentInputTests {
    @Test("A Vietnamese decimal comma parses")
    func decimalCommaParses() {
        #expect(PercentInput.parse("5,6") == Decimal(string: "5.6"))
    }

    @Test("A decimal dot parses the same way")
    func decimalDotParses() {
        #expect(PercentInput.parse("5.6") == Decimal(string: "5.6"))
    }

    @Test("Whole numbers and surrounding whitespace parse")
    func wholeNumbersParse() {
        #expect(PercentInput.parse(" 6 ") == 6)
    }

    @Test("Empty and nonnumeric text is rejected")
    func invalidTextIsRejected() {
        #expect(PercentInput.parse("") == nil)
        #expect(PercentInput.parse("   ") == nil)
        #expect(PercentInput.parse("sáu phẩy một") == nil)
        #expect(PercentInput.parse("5,6 đồng") == nil)
        #expect(PercentInput.parse("5,6,7") == nil)
        #expect(PercentInput.parse("5 6") == nil)
    }

    @Test("A trailing percent sign is accepted")
    func trailingPercentSignIsAccepted() {
        #expect(PercentInput.parse("5,6%") == Decimal(string: "5.6"))
        #expect(PercentInput.parse("6 %") == 6)
    }

    @Test("Negative rates parse so validation can reject them by range")
    func negativeRatesParse() {
        #expect(PercentInput.parse("-1") == -1)
    }

    @Test("Formatting drops trailing zeros and keeps two fraction digits")
    func formattingIsCompact() {
        #expect(PercentInput.format(6) == "6")
        #expect(PercentInput.format(Decimal(string: "5.6") ?? 0) == "5,6")
    }
}
