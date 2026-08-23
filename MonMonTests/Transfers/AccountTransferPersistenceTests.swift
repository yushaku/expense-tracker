import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Account transfer persistence")
@MainActor
struct AccountTransferPersistenceTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CashAccount.self, MoneyTransaction.self, TransactionCategory.self,
            SavingsDeposit.self, FundHolding.self, AccountTransfer.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAccount(
        name: String,
        kind: CashAccountKind = .bank,
        openingBalance: Decimal
    ) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    @Test("A transfer round trips through the store")
    func transferRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bank = makeAccount(name: "Techcombank", openingBalance: 10_000_000)
        let wallet = makeAccount(name: "Wallet", kind: .cash, openingBalance: 0)
        context.insert(bank)
        context.insert(wallet)

        let draft = TransferDraft(
            amountText: "2.000.000",
            occurredAt: occurredAt,
            note: "Cash for the week",
            sourceAccountID: bank.id,
            destinationAccountID: wallet.id
        )
        context.insert(
            try draft.makeTransfer(
                id: UUID(),
                createdAt: occurredAt,
                availableSourceBalance: 10_000_000
            )
        )
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<AccountTransfer>()).first)

        #expect(stored.amount == 2_000_000)
        #expect(stored.note == "Cash for the week")
        #expect(stored.sourceAccountID == bank.id)
        #expect(stored.destinationAccountID == wallet.id)
        #expect(stored.currencyCode == VNDCurrency.code)
    }

    @Test("A stored transfer moves both balances and leaves the total alone")
    func storedTransferMovesBothBalances() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bank = makeAccount(name: "Techcombank", openingBalance: 10_000_000)
        let wallet = makeAccount(name: "Wallet", kind: .cash, openingBalance: 1_000_000)
        context.insert(bank)
        context.insert(wallet)

        let draft = TransferDraft(
            amountText: "2.000.000",
            occurredAt: occurredAt,
            sourceAccountID: bank.id,
            destinationAccountID: wallet.id
        )
        context.insert(
            try draft.makeTransfer(
                id: UUID(),
                createdAt: occurredAt,
                availableSourceBalance: 10_000_000
            )
        )
        try context.save()

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let storedBank = try #require(accounts.first { $0.id == bank.id })
        let storedWallet = try #require(accounts.first { $0.id == wallet.id })

        #expect(
            CashBalanceSummary.available(
                for: storedBank,
                deposits: [],
                holdings: [],
                transactions: [],
                transfers: transfers
            ) == 8_000_000
        )
        #expect(
            CashBalanceSummary.available(
                for: storedWallet,
                deposits: [],
                holdings: [],
                transactions: [],
                transfers: transfers
            ) == 3_000_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(
                of: accounts,
                deposits: [],
                holdings: [],
                transactions: [],
                transfers: transfers
            ) == 11_000_000
        )
    }

    @Test("Deleting a transfer returns both balances to what they were")
    func deletingATransferRestoresBothBalances() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bank = makeAccount(name: "Techcombank", openingBalance: 10_000_000)
        let wallet = makeAccount(name: "Wallet", kind: .cash, openingBalance: 1_000_000)
        context.insert(bank)
        context.insert(wallet)

        let draft = TransferDraft(
            amountText: "2.000.000",
            occurredAt: occurredAt,
            sourceAccountID: bank.id,
            destinationAccountID: wallet.id
        )
        let transfer = try draft.makeTransfer(
            id: UUID(),
            createdAt: occurredAt,
            availableSourceBalance: 10_000_000
        )
        context.insert(transfer)
        try context.save()

        context.delete(transfer)
        try context.save()

        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let storedBank = try #require(
            try context.fetch(FetchDescriptor<CashAccount>()).first { $0.id == bank.id }
        )

        #expect(transfers.isEmpty)
        #expect(
            CashBalanceSummary.available(
                for: storedBank,
                deposits: [],
                holdings: [],
                transactions: [],
                transfers: transfers
            ) == 10_000_000
        )
    }

    @Test("Recorded income and a transfer stack on the same account")
    func transfersAndTransactionsAddUpTogether() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bank = makeAccount(name: "Techcombank", openingBalance: 10_000_000)
        let wallet = makeAccount(name: "Wallet", kind: .cash, openingBalance: 0)
        context.insert(bank)
        context.insert(wallet)

        context.insert(
            try TransactionDraft(
                kind: .income,
                amountText: "5.000.000",
                occurredAt: occurredAt,
                accountID: bank.id,
                categoryID: UUID()
            )
            .makeTransaction(id: UUID(), createdAt: occurredAt)
        )
        context.insert(
            try TransferDraft(
                amountText: "3.000.000",
                occurredAt: occurredAt,
                sourceAccountID: bank.id,
                destinationAccountID: wallet.id
            )
            .makeTransfer(id: UUID(), createdAt: occurredAt, availableSourceBalance: 15_000_000)
        )
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let storedBank = try #require(
            try context.fetch(FetchDescriptor<CashAccount>()).first { $0.id == bank.id }
        )

        #expect(
            CashBalanceSummary.available(
                for: storedBank,
                deposits: [],
                holdings: [],
                transactions: transactions,
                transfers: transfers
            ) == 12_000_000
        )
    }

    @Test("A transfer is not income or expense, so the Spending totals ignore it")
    func transfersStayOutOfTheSpendingTotals() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let bank = makeAccount(name: "Techcombank", openingBalance: 10_000_000)
        let wallet = makeAccount(name: "Wallet", kind: .cash, openingBalance: 0)
        context.insert(bank)
        context.insert(wallet)

        context.insert(
            try TransferDraft(
                amountText: "3.000.000",
                occurredAt: occurredAt,
                sourceAccountID: bank.id,
                destinationAccountID: wallet.id
            )
            .makeTransfer(id: UUID(), createdAt: occurredAt, availableSourceBalance: 10_000_000)
        )
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(transactions.isEmpty)
        #expect(TransactionSummary.totalIncome(of: transactions) == 0)
        #expect(TransactionSummary.totalExpense(of: transactions) == 0)
        #expect(TransactionSummary.net(of: transactions) == 0)
    }
}
