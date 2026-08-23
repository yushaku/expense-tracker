import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund holding persistence")
@MainActor
struct FundHoldingPersistenceTests {
    private let navAsOf = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CashAccount.self, SavingsDeposit.self, FundHolding.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeHolding(
        units: Decimal = 1_000,
        averageCostPerUnit: Decimal = 20_000,
        currentNAVPerUnit: Decimal = 25_000,
        sourceAccountID: UUID? = nil
    ) -> FundHolding {
        FundHolding(
            id: UUID(),
            name: "VinaCapital VESAF",
            symbol: "VESAF",
            kind: .fund,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit,
            navAsOf: navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: navAsOf,
            sourceAccountID: sourceAccountID
        )
    }

    @Test("Saving and fetching preserves every holding field")
    func savingAndFetchingPreservesEveryField() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let id = try #require(UUID(uuidString: "3F4E2B70-96C1-4D2E-8A55-7B0D9C1E4A22"))
        let sourceAccountID = try #require(
            UUID(uuidString: "C51A1D18-2C4E-4A26-8B0B-1E51D6A2F0C4")
        )
        let createdAt = Date(timeIntervalSince1970: 1_700_086_400)
        let units = try #require(Decimal(string: "1234.5678"))
        let nav = try #require(Decimal(string: "27431.28"))
        let holding = FundHolding(
            id: id,
            name: "VinaCapital VESAF",
            symbol: "VESAF",
            kind: .etf,
            units: units,
            averageCostPerUnit: 24_500,
            currentNAVPerUnit: nav,
            navAsOf: navAsOf,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt,
            sourceAccountID: sourceAccountID
        )

        context.insert(holding)
        try context.save()

        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let savedHolding = try #require(holdings.first)

        #expect(holdings.count == 1)
        #expect(savedHolding.id == id)
        #expect(savedHolding.name == "VinaCapital VESAF")
        #expect(savedHolding.symbol == "VESAF")
        #expect(savedHolding.kind == .etf)
        #expect(savedHolding.units == units)
        #expect(savedHolding.averageCostPerUnit == 24_500)
        #expect(savedHolding.currentNAVPerUnit == nav)
        #expect(savedHolding.navAsOf == navAsOf)
        #expect(savedHolding.currencyCode == "VND")
        #expect(savedHolding.createdAt == createdAt)
        #expect(savedHolding.sourceAccountID == sourceAccountID)
    }

    @Test("A holding with no funding source stores no account id")
    func unlinkedHoldingStoresNoAccountID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(makeHolding())
        try context.save()

        let savedHolding = try #require(
            try context.fetch(FetchDescriptor<FundHolding>()).first
        )

        #expect(savedHolding.sourceAccountID == nil)
    }

    @Test("Deleting a holding restores the account's available balance")
    func deletingHoldingRestoresAvailableBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 148_900_000,
            currencyCode: VNDCurrency.code,
            createdAt: navAsOf
        )
        context.insert(account)
        let holding = makeHolding(sourceAccountID: account.id)
        context.insert(holding)
        try context.save()

        var holdings = try context.fetch(FetchDescriptor<FundHolding>())
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: holdings,
                transactions: []
            )
                == 128_900_000
        )

        context.delete(holding)
        try context.save()

        holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())

        #expect(accounts.count == 1)
        #expect(holdings.isEmpty)
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: holdings,
                transactions: []
            )
                == 148_900_000
        )
    }

    @Test("Editing a holding through the draft rewrites its stored values")
    func editingThroughDraftRewritesValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceAccountID = UUID()
        let holding = makeHolding(sourceAccountID: sourceAccountID)
        context.insert(holding)
        try context.save()

        var draft = FundDraft(holding: holding)
        draft.navText = "30.000"

        // Editing adds this holding's own cost basis back to the spendable balance.
        try draft.apply(to: holding, availableSourceBalance: holding.costBasis)
        try context.save()

        let savedHolding = try #require(
            try context.fetch(FetchDescriptor<FundHolding>()).first
        )

        #expect(savedHolding.currentNAVPerUnit == 30_000)
        #expect(savedHolding.units == 1_000)
        #expect(savedHolding.averageCostPerUnit == 20_000)
        #expect(savedHolding.marketValue == 30_000_000)
        #expect(savedHolding.sourceAccountID == sourceAccountID)
    }
}
