import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Recurring generation")
@MainActor
struct RecurringGeneratorTests {
    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

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
        categoryID: UUID? = UUID(),
        frequency: RecurrenceFrequency = .monthly,
        interval: Int = 1,
        anchorDate: Date,
        endDate: Date? = nil,
        isPaused: Bool = false,
        lastGeneratedAt: Date? = nil
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
            lastGeneratedAt: lastGeneratedAt,
            createdAt: anchorDate
        )
    }

    private func transactions(in context: ModelContext) throws -> [MoneyTransaction] {
        try context.fetch(FetchDescriptor<MoneyTransaction>())
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    private func makeJar(percent: Decimal) -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: "Savings",
            allocationPercent: percent,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    @Test("An empty store generates nothing")
    func emptyStoreGeneratesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report == RecurringGenerator.Report())
        #expect(report.isEmpty)
    }

    @Test("A rule catches up on every occurrence it has missed")
    func catchUpWritesEveryMissedOccurrence() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rule = makeRule(anchorDate: try day(2026, 5, 5))
        context.insert(rule)

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report.rules == 1)
        #expect(report.transactions == 4)

        let expected = [
            try day(2026, 5, 5), try day(2026, 6, 5), try day(2026, 7, 5), try day(2026, 8, 5),
        ]
        let written = try transactions(in: context)
        #expect(written.map(\.occurredAt) == expected)
        #expect(written.allSatisfy { $0.sourceRuleID == rule.id })
        #expect(written.allSatisfy { $0.amount == 8_000_000 && $0.kind == .expense })
        #expect(rule.lastGeneratedAt == expected.last)
    }

    @Test("A generated transaction carries the rule's payload")
    func generatedTransactionCarriesThePayload() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let accountID = UUID()
        let categoryID = UUID()
        let rule = makeRule(
            kind: .income,
            amount: 25_000_000,
            note: "Salary",
            accountID: accountID,
            categoryID: categoryID,
            anchorDate: try day(2026, 8, 25)
        )
        context.insert(rule)
        context.insert(makeJar(percent: 100))

        try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 25))

        let written = try #require(try transactions(in: context).first)
        #expect(written.kind == .income)
        #expect(written.amount == 25_000_000)
        #expect(written.note == "Salary")
        #expect(written.accountID == accountID)
        #expect(written.categoryID == categoryID)
        #expect(written.currencyCode == VNDCurrency.code)
        #expect(written.sourceRuleID == rule.id)
        #expect(try IncomeAllocationLifecycle.snapshot(in: written)?.allocatedAmount == 25_000_000)
        #expect(try IncomeAllocationLifecycle.snapshot(in: written)?.isEstimated == false)
    }

    @Test("Running again writes nothing")
    func secondRunWritesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let asOf = try day(2026, 8, 24)
        context.insert(makeRule(anchorDate: try day(2026, 5, 5)))

        try RecurringGenerator.generate(in: context, asOf: asOf)
        let second = try RecurringGenerator.generate(in: context, asOf: asOf)

        #expect(second.isEmpty)
        #expect(try transactions(in: context).count == 4)
    }

    /// The reason `lastGeneratedAt` alone is not enough: a store restored from a
    /// backup, or a rule whose state arrived from a peer, can name a day that is
    /// already recorded.
    @Test("A day already recorded for a rule is never recorded twice")
    func anAlreadyRecordedDayIsSkipped() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let occurredAt = try day(2026, 8, 5)
        let rule = makeRule(anchorDate: occurredAt)
        context.insert(rule)
        context.insert(
            MoneyTransaction(
                id: UUID(),
                kind: .expense,
                amount: 8_000_000,
                occurredAt: occurredAt,
                note: "Rent",
                accountID: rule.accountID,
                categoryID: rule.categoryID,
                sourceRuleID: rule.id,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        )

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report.isEmpty)
        #expect(try transactions(in: context).count == 1)
        #expect(rule.lastGeneratedAt == occurredAt)
    }

    @Test("A hand-typed transaction on the same day never blocks a rule")
    func handTypedTransactionDoesNotBlockGeneration() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let occurredAt = try day(2026, 8, 5)
        let rule = makeRule(anchorDate: occurredAt)
        context.insert(rule)
        context.insert(
            MoneyTransaction(
                id: UUID(),
                kind: .expense,
                amount: 8_000_000,
                occurredAt: occurredAt,
                note: "Rent",
                accountID: rule.accountID,
                categoryID: rule.categoryID,
                sourceRuleID: nil,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        )

        let report = try RecurringGenerator.generate(in: context, asOf: occurredAt)

        #expect(report.transactions == 1)
        #expect(try transactions(in: context).count == 2)
    }

    @Test("A paused rule writes nothing and stays where it was")
    func pausedRuleWritesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rule = makeRule(anchorDate: try day(2026, 5, 5), isPaused: true)
        context.insert(rule)

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report.isEmpty)
        #expect(try transactions(in: context).isEmpty)
        #expect(rule.lastGeneratedAt == nil)
    }

    @Test("An end date stops generation")
    func endDateStopsGeneration() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rule = makeRule(
            anchorDate: try day(2026, 5, 5),
            endDate: try day(2026, 6, 30)
        )
        context.insert(rule)

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        let expected = [try day(2026, 5, 5), try day(2026, 6, 5)]

        #expect(report.transactions == 2)
        #expect(try transactions(in: context).map(\.occurredAt) == expected)
    }

    /// Balances count every transaction whatever its date, so a row dated ahead
    /// of today would move the account before the money did.
    @Test("Nothing is written for a date after today")
    func nothingIsWrittenAhead() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let asOf = try day(2026, 8, 24)
        context.insert(makeRule(frequency: .daily, anchorDate: try day(2026, 8, 20)))

        try RecurringGenerator.generate(in: context, asOf: asOf)

        let written = try transactions(in: context)
        #expect(written.count == 5)
        #expect(written.allSatisfy { $0.occurredAt <= asOf })
    }

    @Test("A rule anchored in the future writes nothing yet")
    func futureAnchorWritesNothingYet() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let rule = makeRule(anchorDate: try day(2026, 9, 5))
        context.insert(rule)

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report.isEmpty)
        #expect(rule.lastGeneratedAt == nil)
    }

    @Test("One pass writes no more than the ceiling and the rest follows next time")
    func ceilingHoldsAndTheRestFollows() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let anchor = try day(2020, 1, 1)
        let asOf = try day(2026, 8, 24)
        context.insert(makeRule(frequency: .daily, anchorDate: anchor))

        let first = try RecurringGenerator.generate(in: context, asOf: asOf)
        #expect(first.transactions == RecurringGenerator.maxOccurrencesPerRule)

        let second = try RecurringGenerator.generate(in: context, asOf: asOf)
        #expect(second.transactions == RecurringGenerator.maxOccurrencesPerRule)
    }

    @Test("Several rules are caught up in one pass")
    func severalRulesAreCaughtUpTogether() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeRule(note: "Rent", anchorDate: try day(2026, 7, 5)))
        context.insert(
            makeRule(kind: .income, note: "Salary", anchorDate: try day(2026, 7, 25))
        )

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        #expect(report.rules == 2)
        #expect(report.transactions == 3)
    }

    @Test("Generated entries survive a fresh context on the same store")
    func generatedEntriesPersist() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeRule(anchorDate: try day(2026, 7, 5)))

        try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        let reopened = ModelContext(container)
        #expect(try transactions(in: reopened).count == 2)
    }
}
