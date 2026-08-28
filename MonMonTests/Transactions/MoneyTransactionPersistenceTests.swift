import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Money transaction persistence")
@MainActor
struct MoneyTransactionPersistenceTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CashAccount.self, MoneyTransaction.self, TransactionCategory.self,
            SavingsDeposit.self, FundHolding.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAccount(openingBalance: Decimal) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .normal,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    @Test("A transaction round trips through the store")
    func transactionRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = makeAccount(openingBalance: 10_000_000)
        let categoryID = UUID()
        context.insert(account)

        let draft = TransactionDraft(
            kind: .expense,
            amountText: "200.000",
            occurredAt: occurredAt,
            note: "Lunch",
            accountID: account.id,
            categoryID: categoryID
        )
        context.insert(try draft.makeTransaction(id: UUID(), createdAt: occurredAt))
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<MoneyTransaction>()).first)

        #expect(stored.kind == .expense)
        #expect(stored.amount == 200_000)
        #expect(stored.note == "Lunch")
        #expect(stored.accountID == account.id)
        #expect(stored.categoryID == categoryID)
        #expect(stored.currencyCode == VNDCurrency.code)
    }

    @Test("Recorded flow lowers and raises the account's available balance")
    func flowMovesTheStoredBalance() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        for draft in [
            TransactionDraft(
                kind: .expense,
                amountText: "200.000",
                occurredAt: occurredAt,
                accountID: account.id,
                categoryID: UUID()
            ),
            TransactionDraft(
                kind: .income,
                amountText: "5.000.000",
                occurredAt: occurredAt,
                accountID: account.id,
                categoryID: UUID()
            ),
        ] {
            context.insert(try draft.makeTransaction(id: UUID(), createdAt: occurredAt))
        }
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 14_800_000
        )
    }

    @Test("Editing through the draft rewrites the stored transaction")
    func editingRewritesTheStoredTransaction() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let transaction = try TransactionDraft(
            kind: .expense,
            amountText: "200.000",
            occurredAt: occurredAt,
            accountID: account.id,
            categoryID: UUID()
        )
        .makeTransaction(id: UUID(), createdAt: occurredAt)
        context.insert(transaction)
        try context.save()

        var draft = TransactionDraft(transaction: transaction)
        draft.amountText = "350.000"
        try draft.apply(to: transaction)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(transactions.first?.amount == 350_000)
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 9_650_000
        )
    }

    @Test("Deleting a transaction returns the balance to what it was")
    func deletingRestoresTheBalance() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = makeAccount(openingBalance: 10_000_000)
        context.insert(account)

        let transaction = try TransactionDraft(
            kind: .expense,
            amountText: "200.000",
            occurredAt: occurredAt,
            accountID: account.id,
            categoryID: UUID()
        )
        .makeTransaction(id: UUID(), createdAt: occurredAt)
        context.insert(transaction)
        try context.save()

        try TransactionDeletion.delete(transaction, from: context)

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(transactions.isEmpty)
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 10_000_000
        )
    }

    @Test("A deleted transaction can be restored with all of its original data")
    func deletedTransactionCanBeRestored() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let account = makeAccount(openingBalance: 10_000_000)
        let transactionID = UUID()
        let categoryID = UUID()
        let ruleID = UUID()
        context.insert(account)

        let transaction = MoneyTransaction(
            id: transactionID,
            kind: .expense,
            amount: 200_000,
            occurredAt: occurredAt,
            note: "Lunch",
            accountID: account.id,
            categoryID: categoryID,
            sourceRuleID: ruleID,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt.addingTimeInterval(-60),
            sourceImportID: "statement-row"
        )
        context.insert(transaction)
        try context.save()

        let deleted = try TransactionDeletion.delete(transaction, from: context)
        let restored = try TransactionDeletion.restore(deleted, in: context)
        let stored = try #require(try context.fetch(FetchDescriptor<MoneyTransaction>()).first)

        #expect(stored === restored)
        #expect(restored.id == transactionID)
        #expect(restored.kind == .expense)
        #expect(restored.amount == 200_000)
        #expect(restored.occurredAt == occurredAt)
        #expect(restored.note == "Lunch")
        #expect(restored.accountID == account.id)
        #expect(restored.categoryID == categoryID)
        #expect(restored.sourceRuleID == ruleID)
        #expect(restored.currencyCode == VNDCurrency.code)
        #expect(restored.createdAt == occurredAt.addingTimeInterval(-60))
        #expect(restored.sourceImportID == "statement-row")
    }
}
