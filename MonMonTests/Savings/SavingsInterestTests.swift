import Foundation
import Testing

@testable import MonMon

@Suite("Savings interest")
struct SavingsInterestTests {
    private let calendar = SavingsInterest.calendar

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return try #require(calendar.date(from: components))
    }

    @Test("Maturity date adds the term in months")
    func maturityDateAddsTerm() throws {
        let openedAt = try date(2026, 1, 10)
        let maturity = SavingsInterest.maturityDate(openedAt: openedAt, termMonths: 6)

        #expect(maturity == (try date(2026, 7, 10)))
    }

    @Test("Maturity date clamps to the last day of a shorter month")
    func maturityDateClampsShortMonth() throws {
        let openedAt = try date(2026, 1, 31)
        let maturity = SavingsInterest.maturityDate(openedAt: openedAt, termMonths: 1)

        #expect(maturity == (try date(2026, 2, 28)))
    }

    @Test("Day count spans whole days between two dates")
    func dayCountSpansWholeDays() throws {
        let start = try date(2026, 1, 10)
        let end = try date(2026, 7, 10)

        #expect(SavingsInterest.dayCount(from: start, to: end) == 181)
    }

    @Test("Interest follows principal times rate times days over 365")
    func interestUsesActualDays() {
        let interest = SavingsInterest.projectedInterest(
            principal: 100_000_000,
            annualRatePercent: Decimal(string: "5.6") ?? 0,
            days: 181
        )

        // 100_000_000 × 0.056 × 181 / 365 = 2_776_986.30…
        #expect(interest == 2_776_986)
    }

    @Test("A full year of interest equals the annual rate")
    func fullYearInterestEqualsRate() {
        let interest = SavingsInterest.projectedInterest(
            principal: 200_000_000,
            annualRatePercent: 6,
            days: 365
        )

        #expect(interest == 12_000_000)
    }

    @Test("Zero rate, zero principal, and zero days earn nothing")
    func degenerateInputsEarnNothing() {
        #expect(
            SavingsInterest.projectedInterest(
                principal: 100_000_000,
                annualRatePercent: 0,
                days: 365
            ) == 0
        )
        #expect(
            SavingsInterest.projectedInterest(
                principal: 0,
                annualRatePercent: 6,
                days: 365
            ) == 0
        )
        #expect(
            SavingsInterest.projectedInterest(
                principal: 100_000_000,
                annualRatePercent: 6,
                days: 0
            ) == 0
        )
    }

    @Test("Maturity value adds rounded interest to the principal")
    func maturityValueAddsInterest() {
        let value = SavingsInterest.maturityValue(
            principal: 100_000_000,
            annualRatePercent: Decimal(string: "5.6") ?? 0,
            days: 181
        )

        #expect(value == 102_776_986)
    }
}
