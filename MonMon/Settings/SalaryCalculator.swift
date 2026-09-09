import Foundation

/// Monthly resident-employee estimate. Sources and scope: docs/salary-calculator.md.
enum SalaryCalculator {
    enum Period: String, CaseIterable, Identifiable {
        case firstHalf = "Jan–Jun 2026"
        case secondHalf = "Jul–Dec 2026"
        var id: Self { self }
        var baseSalary: Decimal { self == .firstHalf ? 2_340_000 : 2_530_000 }
    }

    enum Region: Int, CaseIterable, Identifiable {
        case i = 1, ii, iii, iv
        var id: Self { self }
        var label: String {
            switch self {
            case .i: "I"
            case .ii: "II"
            case .iii: "III"
            case .iv: "IV"
            }
        }
        var minimum: Decimal {
            switch self {
            case .i: 5_310_000
            case .ii: 4_730_000
            case .iii: 4_140_000
            case .iv: 3_700_000
            }
        }
    }

    struct Result: Equatable {
        let gross: Decimal
        let social: Decimal
        let health: Decimal
        let unemployment: Decimal
        let deductions: Decimal
        let taxable: Decimal
        let tax: Decimal
        var net: Decimal { gross - social - health - unemployment - tax }
    }

    static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return output
    }

    static func progressiveTax(_ taxable: Decimal) -> Decimal {
        let widths: [Decimal] = [10_000_000, 20_000_000, 30_000_000, 40_000_000]
        let rates: [Decimal] = [5, 10, 20, 30]
        var remaining = max(0, taxable)
        var tax: Decimal = 0
        for (width, rate) in zip(widths, rates) {
            let portion = min(remaining, width)
            tax += portion * rate / 100
            remaining -= portion
        }
        return rounded(tax + remaining * 35 / 100)
    }

    static func calculate(
        amount: Decimal, fromNet: Bool = false, dependants: Int = 0,
        period: Period = .secondHalf, region: Region = .i, insuranceSalary: Decimal? = nil
    ) -> Result? {
        guard !amount.isNaN, amount > 0, amount <= 1_000_000_000_000,
            (0...20).contains(dependants)
        else { return nil }
        if let insuranceSalary {
            guard !insuranceSalary.isNaN, insuranceSalary >= 0,
                insuranceSalary <= 1_000_000_000_000
            else { return nil }
        }
        func breakdown(_ gross: Decimal) -> Result {
            let base = insuranceSalary ?? gross
            let capped = min(base, period.baseSalary * 20)
            let social = rounded(capped * 8 / 100)
            let health = rounded(capped * 15 / 1_000)
            let unemployment = rounded(min(base, region.minimum * 20) / 100)
            let deductions = Decimal(15_500_000) + Decimal(dependants) * 6_200_000
            let taxable = max(0, gross - social - health - unemployment - deductions)
            return Result(
                gross: gross, social: social, health: health, unemployment: unemployment,
                deductions: deductions, taxable: taxable, tax: progressiveTax(taxable)
            )
        }
        let target = rounded(amount)
        if !fromNet {
            let result = breakdown(target)
            return result.net >= 0 ? result : nil
        }
        // Search whole dong, returning the smallest gross that reaches the requested net.
        var low: Decimal = 0
        var high = target * 2 + 20_000_000
        while high - low > 1 {
            var midpoint = (low + high) / 2
            var floor = Decimal()
            NSDecimalRound(&floor, &midpoint, 0, .down)
            if breakdown(floor).net >= target { high = floor } else { low = floor }
        }
        return breakdown(high)
    }
}

enum SalaryRecurring {
    static func categoryID(in categories: [TransactionCategory]) -> UUID? {
        categories.first { $0.id == CategorySeed.defaultID(for: .income) && $0.kind == .income }?.id
            ?? categories.first {
                $0.kind == .income && ["salary", "lương"].contains($0.name.lowercased())
            }?.id
    }

    static func first(in rules: [RecurringRule], categories: [TransactionCategory])
        -> RecurringRule?
    {
        let salaryIDs = Set(
            categories.filter {
                $0.kind == .income
                    && ($0.id == CategorySeed.defaultID(for: .income)
                        || ["salary", "lương"].contains($0.name.lowercased()))
            }.map(\.id))
        return rules.filter {
            $0.kind == .income && $0.currencyCode == VNDCurrency.code
                && $0.frequency == .monthly && $0.interval == 1
                && $0.categoryID.map(salaryIDs.contains) == true
        }.min {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }

    static func draft(
        net: Decimal, rule: RecurringRule?, accountID: UUID?, categoryID: UUID?,
        name: String, date: Date
    ) -> RecurringRuleDraft {
        var draft =
            rule.map(RecurringRuleDraft.init(rule:))
            ?? RecurringRuleDraft(
                kind: .income, note: name, accountID: accountID,
                categoryID: categoryID, anchorDate: date
            )
        draft.amountText = VNDCurrency.formatPlain(net)
        return draft
    }
}
