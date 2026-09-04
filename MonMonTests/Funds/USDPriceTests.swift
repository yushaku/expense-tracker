import Foundation
import Testing

@testable import MonMon

@Suite("USD price entry")
struct USDPriceTests {
    @Test("A dollar price parses with either decimal mark")
    func eitherDecimalMarkParses() {
        #expect(USDPrice.parse("79463.25") == Decimal(string: "79463.25"))
        #expect(USDPrice.parse("79463,25") == Decimal(string: "79463.25"))
    }

    @Test("Grouped digits are rejected so a stray separator is never a silent zero")
    func groupedDigitsAreRejected() {
        #expect(USDPrice.parse("79.463,25") == nil)
        #expect(USDPrice.parse("") == nil)
        #expect(USDPrice.parse("seventy") == nil)
    }

    @Test("Converting to đồng multiplies by the rate")
    func conversionMultiplies() {
        #expect(USDPrice.inDong(79_463, rate: 26_058) == 2_070_646_854)
    }

    /// The conversion is deliberately unrounded: a coin worth a fraction of a
    /// đồng has to keep a price, or a position in it fails validation at zero.
    @Test("A sub-đồng price survives the conversion")
    func subDongPriceSurvives() throws {
        let dollars = try #require(Decimal(string: "0.000001"))
        let dong = try #require(USDPrice.inDong(dollars, rate: 26_058))

        #expect(dong > 0)
        #expect(dong == Decimal(string: "0.026058"))
    }

    @Test("A dollar figure round-trips through đồng at the same rate")
    func roundTripsAtTheSameRate() throws {
        let dollars = try #require(Decimal(string: "79463.25"))
        let dong = try #require(USDPrice.inDong(dollars, rate: 26_058))

        #expect(USDPrice.inDollars(dong, rate: 26_058) == dollars)
    }

    @Test("A missing or nonsensical rate converts nothing")
    func nonPositiveRateConvertsNothing() {
        #expect(USDPrice.inDong(100, rate: 0) == nil)
        #expect(USDPrice.inDong(100, rate: -1) == nil)
        #expect(USDPrice.inDong(0, rate: 26_058) == nil)
        #expect(USDPrice.inDollars(100, rate: 0) == nil)
    }

    @Test("Formatting drops trailing zeros and never groups")
    func formattingIsCompact() throws {
        #expect(USDPrice.format(79_463) == "79463")
        #expect(USDPrice.format(try #require(Decimal(string: "0.00000123"))) == "0,00000123")
    }

    @Test("A formatted dollar price parses back to the same value")
    func formatAndParseRoundTrip() throws {
        let dollars = try #require(Decimal(string: "1234.5678"))

        #expect(USDPrice.parse(USDPrice.format(dollars)) == dollars)
    }

    @Test("Each entry currency carries a symbol and a name")
    func entryCurrenciesAreLabelled() {
        #expect(PriceEntryCurrency.vnd.symbol == "₫")
        #expect(PriceEntryCurrency.usd.symbol == "$")
        for currency in PriceEntryCurrency.allCases {
            #expect(!currency.displayNameKey.isEmpty)
        }
    }
}
