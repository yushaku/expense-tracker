import Foundation
import Testing

@testable import MonMon

@Suite("Salary calculator")
struct SalaryCalculatorTests {
    @Test func standardSalary() throws {
        let value = try #require(SalaryCalculator.calculate(amount: 30_000_000))
        #expect(value.social == 2_400_000)
        #expect(value.health == 450_000)
        #expect(value.unemployment == 300_000)
        #expect(value.taxable == 11_350_000)
        #expect(value.tax == 635_000)
        #expect(value.net == 26_215_000)
    }

    @Test func taxBoundaries() {
        for (income, tax) in [
            (0, 0), (10_000_000, 500_000), (30_000_000, 2_500_000),
            (60_000_000, 8_500_000), (100_000_000, 20_500_000), (110_000_000, 24_000_000),
        ] {
            #expect(SalaryCalculator.progressiveTax(Decimal(income)) == Decimal(tax))
        }
    }

    @Test func insuranceCapsAndPeriod() throws {
        let first = try #require(
            SalaryCalculator.calculate(amount: 200_000_000, period: .firstHalf, region: .iv))
        let second = try #require(
            SalaryCalculator.calculate(amount: 200_000_000, period: .secondHalf, region: .i))
        #expect(first.social == 3_744_000)
        #expect(first.health == 702_000)
        #expect(first.unemployment == 740_000)
        #expect(second.social == 4_048_000)
        #expect(second.health == 759_000)
        #expect(second.unemployment == 1_062_000)
    }

    @Test func dependantsAndCustomInsurance() throws {
        let value = try #require(
            SalaryCalculator.calculate(
                amount: 30_000_000, dependants: 2, insuranceSalary: 5_000_000))
        #expect(value.deductions == 27_900_000)
        #expect(value.tax == 78_750)
        #expect(value.net == 29_396_250)
    }

    @Test func reverseAcrossBracketsAndCaps() throws {
        for gross in [
            5_000_000, 17_318_436, 30_000_000, 50_600_000, 80_000_000, 150_000_000, 999_999_999_999,
        ] {
            for period in SalaryCalculator.Period.allCases {
                for base: Decimal? in [nil, 8_000_000] {
                    let forward = try #require(
                        SalaryCalculator.calculate(
                            amount: Decimal(gross), period: period, insuranceSalary: base))
                    let reverse = try #require(
                        SalaryCalculator.calculate(
                            amount: forward.net, fromNet: true, period: period,
                            insuranceSalary: base))
                    #expect(abs(reverse.net - forward.net) <= 1)
                    #expect(abs(reverse.gross - forward.gross) <= 3)
                }
            }
        }
    }

    @Test func invalidInput() {
        for amount: Decimal in [0, -1, .nan, 1_000_000_000_001] {
            #expect(SalaryCalculator.calculate(amount: amount) == nil)
        }
        #expect(SalaryCalculator.calculate(amount: 10_000_000, dependants: -1) == nil)
        #expect(SalaryCalculator.calculate(amount: 10_000_000, insuranceSalary: -1) == nil)
    }

    @Test @MainActor func recurringSelectionAndDraft() throws {
        let categories = CategorySeed.makeCategories(createdAt: .now)
        let category = try #require(SalaryRecurring.categoryID(in: categories))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = RecurringRule(
            id: UUID(), kind: .income, amount: 20_000_000, note: "My salary",
            accountID: UUID(), categoryID: category, currencyCode: VNDCurrency.code,
            frequency: .monthly, interval: 1, anchorDate: date, endDate: nil,
            isPaused: true, lastGeneratedAt: date, createdAt: date
        )
        let other = RecurringRule(
            id: UUID(), kind: .expense, amount: 1, note: "Salary",
            accountID: UUID(), categoryID: category, currencyCode: VNDCurrency.code,
            frequency: .monthly, interval: 1, anchorDate: date, endDate: nil,
            isPaused: false, lastGeneratedAt: nil, createdAt: .distantPast
        )
        #expect(SalaryRecurring.first(in: [other, rule], categories: categories)?.id == rule.id)
        var expected = RecurringRuleDraft(rule: rule)
        expected.amountText = VNDCurrency.formatPlain(26_215_000)
        let draft = SalaryRecurring.draft(
            net: 26_215_000, rule: rule, accountID: nil, categoryID: nil, name: "Salary", date: .now
        )
        #expect(draft == expected)
        #expect(rule.amount == 20_000_000)
        #expect(rule.lastGeneratedAt == date)
        try draft.apply(to: rule, asOf: date)
        #expect(rule.amount == 26_215_000)
        #expect(rule.lastGeneratedAt == date)
        #expect(rule.isPaused)
        other.kind = .income
        #expect(SalaryRecurring.first(in: [rule, other], categories: categories)?.id == other.id)
        other.frequency = .weekly
        #expect(SalaryRecurring.first(in: [other, rule], categories: categories)?.id == rule.id)
        rule.currencyCode = "USD"
        #expect(SalaryRecurring.first(in: [rule], categories: categories) == nil)
        let new = SalaryRecurring.draft(
            net: 26_215_000, rule: nil, accountID: other.accountID, categoryID: category,
            name: "Salary", date: date)
        #expect(new.kind == .income)
        #expect(new.frequency == .monthly)
        #expect(new.categoryID == category)
        #expect(new.accountID == other.accountID)
        #expect(new.anchorDate == date)
    }
}
