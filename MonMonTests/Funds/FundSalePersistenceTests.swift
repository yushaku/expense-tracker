import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund sale persistence")
@MainActor
struct FundSalePersistenceTests {
    private let referenceDate = FundTestFactory.referenceDate

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("A sale round-trips every field it was written with")
    func saleRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let accountID = UUID()
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )
        let sale = FundSale(
            id: UUID(),
            holdingID: holding.id,
            units: 400,
            pricePerUnit: 26_000,
            fee: 100_000,
            proceedsAccountID: accountID,
            soldAt: referenceDate,
            note: "took profit",
            currencyCode: VNDCurrency.code,
            createdAt: referenceDate
        )

        context.insert(instrument)
        context.insert(holding)
        context.insert(sale)
        try context.save()

        let saved = try #require(try context.fetch(FetchDescriptor<FundSale>()).first)

        #expect(saved.holdingID == holding.id)
        #expect(saved.units == 400)
        #expect(saved.pricePerUnit == 26_000)
        #expect(saved.fee == 100_000)
        #expect(saved.proceedsAccountID == accountID)
        #expect(saved.soldAt == referenceDate)
        #expect(saved.note == "took profit")
        #expect(saved.grossProceeds == 10_400_000)
        #expect(saved.proceeds == 10_300_000)
        #expect(saved.realizedProfitLoss(costPerUnit: holding.averageCostPerUnit) == 2_300_000)
    }

    @Test("The lot behind a saved sale reports only what is left")
    func savedSaleShrinksWhatIsHeld() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )
        context.insert(instrument)
        context.insert(holding)
        context.insert(
            FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)
        )
        try context.save()

        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let sales = try context.fetch(FetchDescriptor<FundSale>())
        let saved = try #require(holdings.first)

        // The lot itself is untouched — only what is derived from it moved.
        #expect(saved.units == 1_000)
        #expect(saved.costBasis == 20_000_000)
        #expect(saved.remainingUnits(sales: sales) == 600)
        #expect(saved.remainingCostBasis(sales: sales) == 12_000_000)
        #expect(saved.marketValue(in: [instrument], sales: sales) == 15_000_000)
    }

    @Test("Deleting a lot deletes the sales that came out of it")
    func deletingALotDeletesItsSales() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )
        let other = FundTestFactory.holding(
            in: instrument,
            units: 500,
            averageCostPerUnit: 21_000
        )
        context.insert(instrument)
        context.insert(holding)
        context.insert(other)
        context.insert(FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000))
        context.insert(FundTestFactory.sale(of: other, units: 100, pricePerUnit: 27_000))
        try context.save()

        // What `FundEditorView.delete()` does: the lot's own sales go with it,
        // and nothing else does.
        let doomed = FundSaleSummary.sales(
            for: holding,
            sales: try context.fetch(FetchDescriptor<FundSale>())
        )
        for sale in doomed {
            context.delete(sale)
        }
        context.delete(holding)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<FundSale>())

        #expect(remaining.count == 1)
        #expect(remaining.first?.holdingID == other.id)
        #expect(try context.fetch(FetchDescriptor<FundHolding>()).count == 1)
    }
}
