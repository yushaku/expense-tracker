import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Savings deposit persistence")
@MainActor
struct SavingsDepositPersistenceTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CashAccount.self, SavingsDeposit.self, FundHolding.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeDeposit(
        name: String = "Techcombank 6 tháng",
        principal: Decimal = 100_000_000,
        rate: Decimal = 6,
        termMonths: Int = 6,
        sourceAccountID: UUID? = nil
    ) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: name,
            principal: principal,
            annualInterestRate: rate,
            termMonths: termMonths,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: sourceAccountID
        )
    }

    @Test("Saving and fetching preserves every deposit field")
    func savingAndFetchingPreservesEveryField() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let id = try #require(UUID(uuidString: "0E7B1E1C-1F5C-4E6C-9E27-6D3C0F4B2A11"))
        let sourceAccountID = try #require(
            UUID(uuidString: "C51A1D18-2C4E-4A26-8B0B-1E51D6A2F0C4")
        )
        let createdAt = Date(timeIntervalSince1970: 1_700_086_400)
        let rate = try #require(Decimal(string: "5.6"))
        let deposit = SavingsDeposit(
            id: id,
            name: "Techcombank 6 tháng",
            principal: 100_000_000,
            annualInterestRate: rate,
            termMonths: 6,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )

        context.insert(deposit)
        try context.save()

        let deposits = try context.fetch(FetchDescriptor<SavingsDeposit>())
        let savedDeposit = try #require(deposits.first)

        #expect(deposits.count == 1)
        #expect(savedDeposit.id == id)
        #expect(savedDeposit.name == "Techcombank 6 tháng")
        #expect(savedDeposit.principal == 100_000_000)
        #expect(savedDeposit.annualInterestRate == rate)
        #expect(savedDeposit.termMonths == 6)
        #expect(savedDeposit.openedAt == openedAt)
        #expect(savedDeposit.currencyCode == "VND")
        #expect(savedDeposit.createdAt == createdAt)
        #expect(savedDeposit.sourceAccountID == sourceAccountID)
    }

    @Test("A deposit with no funding source stores no account id")
    func unlinkedDepositStoresNoAccountID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(makeDeposit())
        try context.save()

        let savedDeposit = try #require(
            try context.fetch(FetchDescriptor<SavingsDeposit>()).first
        )

        #expect(savedDeposit.sourceAccountID == nil)
    }

    @Test("Deleting a deposit restores the account's available balance")
    func deletingDepositRestoresAvailableBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 148_900_000,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
        context.insert(account)
        let deposit = makeDeposit(sourceAccountID: account.id)
        context.insert(deposit)
        try context.save()

        var deposits = try context.fetch(FetchDescriptor<SavingsDeposit>())
        #expect(
            CashBalanceSummary.available(for: account, deposits: deposits, holdings: [])
                == 48_900_000
        )

        context.delete(deposit)
        try context.save()

        deposits = try context.fetch(FetchDescriptor<SavingsDeposit>())
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())

        #expect(accounts.count == 1)
        #expect(deposits.isEmpty)
        #expect(
            CashBalanceSummary.available(for: account, deposits: deposits, holdings: [])
                == 148_900_000
        )
    }

    @Test("Editing a deposit through the draft rewrites its stored values")
    func editingThroughDraftRewritesValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceAccountID = UUID()
        let deposit = makeDeposit(sourceAccountID: sourceAccountID)
        context.insert(deposit)
        try context.save()

        var draft = SavingsDraft(deposit: deposit)
        draft.name = "Techcombank 12 tháng"
        draft.termMonthsText = "12"

        // Editing adds this deposit's own principal back to the spendable balance.
        try draft.apply(to: deposit, availableSourceBalance: deposit.principal)
        try context.save()

        let savedDeposit = try #require(
            try context.fetch(FetchDescriptor<SavingsDeposit>()).first
        )

        #expect(savedDeposit.name == "Techcombank 12 tháng")
        #expect(savedDeposit.termMonths == 12)
        #expect(savedDeposit.principal == 100_000_000)
        #expect(savedDeposit.sourceAccountID == sourceAccountID)
    }
}
