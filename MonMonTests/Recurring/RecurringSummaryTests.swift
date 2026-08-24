import Foundation
import Testing

@testable import MonMon

@Suite("Recurring summary")
struct RecurringSummaryTests {
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) throws -> Date {
        try #require(
            RecurrenceSchedule.calendar.date(
                from: DateComponents(year: year, month: month, day: dayOfMonth)
            )
        )
    }

    private func makeRule(
        kind: TransactionKind = .expense,
        amount: Decimal = 8_000_000,
        note: String = "Rent",
        accountID: UUID = UUID(),
        categoryID: UUID? = nil,
        frequency: RecurrenceFrequency = .monthly,
        interval: Int = 1,
        anchorDate: Date,
        endDate: Date? = nil,
        isPaused: Bool = false
    ) -> RecurringRule {
        RecurringRule(
            id: UUID(),
            kind: kind,
            amount: amount,
            note: note,
            accountID: accountID,
            categoryID: categoryID,
            currencyCode: VNDCurrency.code,
            frequency: frequency,
            interval: interval,
            anchorDate: anchorDate,
            endDate: endDate,
            isPaused: isPaused,
            lastGeneratedAt: nil,
            createdAt: anchorDate
        )
    }

    private func makeAccount() -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeCategory() -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: "Housing",
            kind: .expense,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("Only the rules naming an account are counted for it")
    func rulesAreCountedPerAccount() throws {
        let account = makeAccount()
        let anchor = try day(2026, 8, 5)
        let rules = [
            makeRule(accountID: account.id, anchorDate: anchor),
            makeRule(accountID: account.id, anchorDate: anchor),
            makeRule(anchorDate: anchor),
        ]

        #expect(RecurringSummary.count(for: account, rules: rules) == 2)
    }

    @Test("Only the rules filed under a category are counted for it")
    func rulesAreCountedPerCategory() throws {
        let category = makeCategory()
        let anchor = try day(2026, 8, 5)
        let rules = [
            makeRule(categoryID: category.id, anchorDate: anchor),
            makeRule(categoryID: nil, anchorDate: anchor),
            makeRule(categoryID: UUID(), anchorDate: anchor),
        ]

        #expect(RecurringSummary.count(for: category, rules: rules) == 1)
    }

    @Test("Active and paused rules are told apart")
    func activeAndPausedAreToldApart() throws {
        let anchor = try day(2026, 8, 5)
        let rules = [
            makeRule(anchorDate: anchor),
            makeRule(anchorDate: anchor, isPaused: true),
        ]

        #expect(RecurringSummary.active(rules).count == 1)
        #expect(RecurringSummary.paused(rules).count == 1)
    }

    @Test("The soonest due rule sorts first")
    func soonestDueSortsFirst() throws {
        let asOf = try day(2026, 8, 24)
        let later = makeRule(note: "Rent", anchorDate: try day(2026, 9, 5))
        let sooner = makeRule(note: "Gym", anchorDate: try day(2026, 8, 28))

        let sorted = RecurringSummary.sortedForDisplay([later, sooner], asOf: asOf)

        #expect(sorted.map(\.note) == ["Gym", "Rent"])
    }

    @Test("A rule with nothing left to do sinks below the rest")
    func rulesWithNothingLeftSinkToTheBottom() throws {
        let asOf = try day(2026, 8, 24)
        let paused = makeRule(note: "Netflix", anchorDate: try day(2026, 8, 25), isPaused: true)
        let ended = makeRule(
            note: "Course",
            anchorDate: try day(2026, 1, 5),
            endDate: try day(2026, 6, 5)
        )
        let active = makeRule(note: "Rent", anchorDate: try day(2026, 9, 5))

        let sorted = RecurringSummary.sortedForDisplay([paused, ended, active], asOf: asOf)

        #expect(sorted.first?.note == "Rent")
        #expect(Set(sorted.dropFirst().map(\.note)) == ["Netflix", "Course"])
    }

    @Test("Two rules due on the same day fall back on the name")
    func tiesFallBackOnTheName() throws {
        let asOf = try day(2026, 8, 24)
        let anchor = try day(2026, 8, 28)
        let rent = makeRule(note: "Rent", anchorDate: anchor)
        let gym = makeRule(note: "Gym", anchorDate: anchor)

        let sorted = RecurringSummary.sortedForDisplay([rent, gym], asOf: asOf)

        #expect(sorted.map(\.note) == ["Gym", "Rent"])
    }

    @Test("A monthly rule costs its amount once a month")
    func monthlyRuleCostsItsAmountOnce() throws {
        let rule = makeRule(amount: 8_000_000, anchorDate: try day(2026, 8, 5))

        #expect(RecurringSummary.monthlyAmount(of: rule, asOf: try day(2026, 8, 24)) == 8_000_000)
    }

    /// A weekly and a monthly rule can only be added together once both are
    /// expressed over the same stretch of time.
    @Test("A weekly rule counts every time it falls due in the month")
    func weeklyRuleCountsEveryDueDate() throws {
        let rule = makeRule(amount: 100_000, frequency: .weekly, anchorDate: try day(2026, 8, 3))

        // 3, 10, 17, 24 and 31 August.
        #expect(RecurringSummary.monthlyAmount(of: rule, asOf: try day(2026, 8, 24)) == 500_000)
    }

    @Test("A rule that has not started yet costs nothing this month")
    func futureRuleCostsNothingYet() throws {
        let rule = makeRule(anchorDate: try day(2026, 10, 5))

        #expect(RecurringSummary.monthlyAmount(of: rule, asOf: try day(2026, 8, 24)) == 0)
    }

    @Test("A rule that has ended costs nothing this month")
    func endedRuleCostsNothing() throws {
        let rule = makeRule(
            anchorDate: try day(2026, 1, 5),
            endDate: try day(2026, 6, 5)
        )

        #expect(RecurringSummary.monthlyAmount(of: rule, asOf: try day(2026, 8, 24)) == 0)
    }

    @Test("A paused rule costs nothing")
    func pausedRuleCostsNothing() throws {
        let rule = makeRule(anchorDate: try day(2026, 8, 5), isPaused: true)

        #expect(RecurringSummary.monthlyAmount(of: rule, asOf: try day(2026, 8, 24)) == 0)
    }

    @Test("The monthly net is what comes in less what goes out")
    func monthlyNetIsIncomeLessExpense() throws {
        let asOf = try day(2026, 8, 24)
        let rules = [
            makeRule(
                kind: .income,
                amount: 25_000_000,
                note: "Salary",
                anchorDate: try day(2026, 8, 25)
            ),
            makeRule(amount: 8_000_000, note: "Rent", anchorDate: try day(2026, 8, 5)),
            makeRule(amount: 260_000, note: "Netflix", anchorDate: try day(2026, 8, 12)),
        ]

        #expect(RecurringSummary.monthlyNet(of: rules, asOf: asOf) == 16_740_000)
    }
}
