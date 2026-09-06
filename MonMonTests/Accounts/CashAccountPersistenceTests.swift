import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Cash account persistence")
@MainActor
struct CashAccountPersistenceTests {
    @Test("Saving and fetching preserves every cash account field")
    func savingAndFetchingPreservesEveryField() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CashAccount.self,
            configurations: configuration
        )
        let context = container.mainContext
        let id = try #require(UUID(uuidString: "8B9F388D-0DF7-4C70-A269-00C3F6A754AF"))
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let openingBalance = Decimal(12_345_678)
        let account = CashAccount(
            id: id,
            name: "Visa",
            kind: .credit,
            openingBalance: -openingBalance,
            creditLimit: 50_000_000,
            currencyCode: "VND",
            createdAt: createdAt
        )

        context.insert(account)
        try context.save()

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let savedAccount = try #require(accounts.first)

        #expect(accounts.count == 1)
        #expect(savedAccount.id == id)
        #expect(savedAccount.name == "Visa")
        #expect(savedAccount.kind == .credit)
        #expect(savedAccount.openingBalance == -openingBalance)
        #expect(savedAccount.creditLimit == 50_000_000)
        #expect(savedAccount.currencyCode == "VND")
        #expect(savedAccount.createdAt == createdAt)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAccount(name: String, openingBalance: Decimal = .zero) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: .normal,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("Deleting an account moves its records and its balance to another")
    func deletingAnAccountMovesItsRecordsAndBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = makeAccount(name: "Old wallet", openingBalance: 2_000_000)
        let keeper = makeAccount(name: "Techcombank", openingBalance: 5_000_000)
        context.insert(old)
        context.insert(keeper)

        let transaction = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 150_000,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Coffee",
            accountID: old.id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        context.insert(transaction)
        try context.save()

        #expect(AccountMerge.linkedRecordCount(for: old, in: context) == 1)

        try AccountMerge.move(from: old, to: keeper, in: context)

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        #expect(accounts.map(\.name) == ["Techcombank"])
        // The balance goes with the records, so net worth is what it was.
        #expect(keeper.openingBalance == 7_000_000)
        #expect(transaction.accountID == keeper.id)
    }

    /// Both ends would name the same account, and money moved to where it
    /// already is moves nothing.
    @Test("A transfer between the two accounts goes rather than becoming a loop")
    func transfersBetweenTheTwoAccountsAreDropped() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = makeAccount(name: "Old wallet")
        let keeper = makeAccount(name: "Techcombank")
        let other = makeAccount(name: "Cash")
        context.insert(old)
        context.insert(keeper)
        context.insert(other)

        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let loop = AccountTransfer(
            id: UUID(),
            amount: 500_000,
            occurredAt: occurredAt,
            note: "",
            sourceAccountID: old.id,
            destinationAccountID: keeper.id,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        let survivor = AccountTransfer(
            id: UUID(),
            amount: 300_000,
            occurredAt: occurredAt,
            note: "",
            sourceAccountID: other.id,
            destinationAccountID: old.id,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        context.insert(loop)
        context.insert(survivor)
        try context.save()

        #expect(AccountMerge.linkedRecordCount(for: old, in: context) == 2)

        try AccountMerge.move(from: old, to: keeper, in: context)

        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        #expect(transfers.count == 1)
        #expect(transfers.first?.destinationAccountID == keeper.id)
        #expect(transfers.first?.sourceAccountID == other.id)
    }
}
