import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Account seed")
struct AccountSeedTests {
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("An empty store gains the anchor account")
    func emptyStoreGainsAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let account = AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)

        #expect(account.id == AccountSeed.unassignedID)
        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 1)
    }

    /// This runs on every launch, so a second call has to be a no-op. If it were
    /// not, the store would gain one anchor per launch.
    @Test("Seeding twice leaves one account")
    func seedingTwiceLeavesOne() throws {
        let container = try makeContainer()
        let context = container.mainContext

        AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)
        AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)

        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 1)
    }

    /// Matched on the id, not the name, so renaming the anchor in the UI does
    /// not make the next launch write a second one.
    @Test("A renamed anchor is still recognised")
    func renamedAnchorIsRecognised() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let account = AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)
        account.name = "Ví lạc"
        try context.save()

        AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)

        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 1)
    }

    @Test("Other accounts are left alone")
    func otherAccountsAreLeftAlone() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(
            CashAccount(
                id: UUID(),
                name: "Techcombank",
                kind: .bank,
                openingBalance: 148_900_000,
                currencyCode: VNDCurrency.code,
                createdAt: referenceDate
            )
        )
        try context.save()

        AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)

        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 2)
    }

    /// The point of the whole file: a record written with no account of its own
    /// still names one that exists.
    @Test("A defaulted foreign key resolves to the anchor")
    func defaultedForeignKeyResolvesToTheAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchor = AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)

        let transaction = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 50_000,
            occurredAt: referenceDate,
            note: "",
            accountID: AccountSeed.unassignedID,
            categoryID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: referenceDate
        )
        context.insert(transaction)
        try context.save()

        #expect(transaction.accountID == anchor.id)
        #expect(TransactionSummary.count(for: anchor, transactions: [transaction]) == 1)
        #expect(TransactionSummary.netFlow(for: anchor, transactions: [transaction]) == -50_000)
    }

    @Test("Only the anchor is the anchor")
    func onlyTheAnchorIsTheAnchor() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let anchor = AccountSeed.ensureUnassignedExists(in: context, createdAt: referenceDate)
        let other = CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: referenceDate
        )

        #expect(AccountSeed.isUnassigned(anchor))
        #expect(!AccountSeed.isUnassigned(other))
    }
}
