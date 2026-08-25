import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Recurring rule persistence")
@MainActor
struct RecurringRulePersistenceTests {
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

    private func makeAccount(openingBalance: Decimal) throws -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: try day(2026, 1, 1)
        )
    }

    private func available(
        _ account: CashAccount,
        in context: ModelContext
    ) throws -> Decimal {
        CashBalanceSummary.available(
            for: account,
            deposits: try context.fetch(FetchDescriptor<SavingsDeposit>()),
            holdings: try context.fetch(FetchDescriptor<FundHolding>()),
            withdrawals: try context.fetch(FetchDescriptor<SavingsWithdrawal>()),
            transactions: try context.fetch(FetchDescriptor<MoneyTransaction>()),
            transfers: try context.fetch(FetchDescriptor<AccountTransfer>()),
            debts: try context.fetch(FetchDescriptor<Debt>()),
            payments: try context.fetch(FetchDescriptor<DebtPayment>()),
            sales: []
        )
    }

    @Test("A rule round trips through the store")
    func ruleRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = try makeAccount(openingBalance: 10_000_000)
        let categoryID = UUID()
        let anchor = try day(2026, 8, 5)
        let end = try day(2027, 8, 5)
        context.insert(account)

        let draft = RecurringRuleDraft(
            kind: .expense,
            amountText: "8.000.000",
            note: "Rent",
            accountID: account.id,
            categoryID: categoryID,
            frequency: .monthly,
            intervalText: "2",
            anchorDate: anchor,
            hasEndDate: true,
            endDate: end
        )
        context.insert(
            try draft.makeRule(id: UUID(), createdAt: anchor, asOf: try day(2026, 8, 24))
        )
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<RecurringRule>()).first)
        #expect(stored.kind == .expense)
        #expect(stored.amount == 8_000_000)
        #expect(stored.note == "Rent")
        #expect(stored.accountID == account.id)
        #expect(stored.categoryID == categoryID)
        #expect(stored.currencyCode == VNDCurrency.code)
        #expect(stored.frequency == .monthly)
        #expect(stored.interval == 2)
        #expect(stored.anchorDate == anchor)
        #expect(stored.endDate == end)
        #expect(stored.isPaused == false)
        #expect(stored.lastGeneratedAt == nil)
    }

    /// The whole point of writing a real transaction: nothing else has to learn
    /// what a rule is for the balance to follow it.
    @Test("A generated entry moves the account balance")
    func generatedEntryMovesTheBalance() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = try makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let draft = RecurringRuleDraft(
            amountText: "2.000.000",
            note: "Rent",
            accountID: account.id,
            categoryID: UUID(),
            anchorDate: try day(2026, 6, 5)
        )
        context.insert(
            try draft.makeRule(
                id: UUID(),
                createdAt: try day(2026, 6, 5),
                asOf: try day(2026, 8, 24)
            )
        )
        try context.save()

        try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        // 10.000.000 − 3 × 2.000.000
        #expect(try available(account, in: context) == 4_000_000)
    }

    @Test("A rule on its own moves no balance at all")
    func aRuleAloneMovesNothing() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = try makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let draft = RecurringRuleDraft(
            amountText: "2.000.000",
            note: "Rent",
            accountID: account.id,
            categoryID: UUID(),
            anchorDate: try day(2026, 9, 5)
        )
        context.insert(
            try draft.makeRule(
                id: UUID(),
                createdAt: try day(2026, 8, 24),
                asOf: try day(2026, 8, 24)
            )
        )
        try context.save()

        #expect(try available(account, in: context) == 10_000_000)
    }

    /// A generated entry records money that really moved, so deleting the rule
    /// that wrote it must not take it back.
    @Test("Deleting a rule keeps what it already recorded")
    func deletingARuleKeepsItsEntries() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = try makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let draft = RecurringRuleDraft(
            amountText: "2.000.000",
            note: "Rent",
            accountID: account.id,
            categoryID: UUID(),
            anchorDate: try day(2026, 6, 5)
        )
        let rule = try draft.makeRule(
            id: UUID(),
            createdAt: try day(2026, 6, 5),
            asOf: try day(2026, 8, 24)
        )
        context.insert(rule)
        try context.save()
        try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        context.delete(rule)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<RecurringRule>()).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 3)
        #expect(try available(account, in: context) == 4_000_000)
    }

    /// The rule is gone, so nothing generates again — the entries it left behind
    /// are ordinary transactions from here on.
    @Test("A deleted rule generates nothing more")
    func aDeletedRuleGeneratesNothingMore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = try makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let rule = try RecurringRuleDraft(
            amountText: "2.000.000",
            note: "Rent",
            accountID: account.id,
            categoryID: UUID(),
            anchorDate: try day(2026, 6, 5)
        )
        .makeRule(id: UUID(), createdAt: try day(2026, 6, 5), asOf: try day(2026, 8, 24))
        context.insert(rule)
        try context.save()
        try RecurringGenerator.generate(in: context, asOf: try day(2026, 8, 24))

        context.delete(rule)
        try context.save()

        let report = try RecurringGenerator.generate(in: context, asOf: try day(2026, 12, 31))

        #expect(report.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 3)
    }

    @Test("A rule survives a fresh context on the same store")
    func rulePersistsAcrossContexts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let anchor = try day(2026, 8, 5)
        context.insert(
            try RecurringRuleDraft(
                amountText: "8.000.000",
                note: "Rent",
                accountID: UUID(),
                categoryID: UUID(),
                anchorDate: anchor
            )
            .makeRule(id: UUID(), createdAt: anchor, asOf: try day(2026, 8, 24))
        )
        try context.save()

        let reopened = ModelContext(container)
        let stored = try #require(try reopened.fetch(FetchDescriptor<RecurringRule>()).first)
        #expect(stored.note == "Rent")
        #expect(stored.anchorDate == anchor)
    }
}
