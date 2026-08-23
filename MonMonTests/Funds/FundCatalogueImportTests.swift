import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Fund catalogue import")
@MainActor
struct FundCatalogueImportTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func importer(_ body: String, statusCode: Int = 200) -> FundCatalogueImport {
        let transport = FixtureTransport([
            "products/filter": .init(body, statusCode: statusCode)
        ])
        return FundCatalogueImport(provider: FmarketQuoteProvider(transport: transport))
    }

    @Test("The listing arrives priced, so importing costs one request")
    func listingArrivesPriced() async throws {
        let importer = importer(FundQuoteFixtures.fmarketCatalogue)

        await importer.load(existing: [])

        #expect(importer.phase == .loaded)
        #expect(importer.candidates.map(\.symbol) == ["AEIF", "UMMF", "VESAF"])

        let vesaf = try #require(importer.candidates.first { $0.symbol == "VESAF" })
        #expect(vesaf.pricePerUnit == Decimal(string: "31581.76"))
        #expect(vesaf.kind == .fund)
        #expect(vesaf.priceAsOf != nil)
    }

    /// A listing with no `productNavChange` still imports; Refresh fills it in.
    @Test("A fund with no date still imports")
    func fundWithoutDateStillImports() async throws {
        let importer = importer(FundQuoteFixtures.fmarketCatalogue)
        await importer.load(existing: [])

        let aeif = try #require(importer.candidates.first { $0.symbol == "AEIF" })

        #expect(aeif.pricePerUnit == Decimal(string: "9348.31"))
        #expect(aeif.priceAsOf == nil)
    }

    @Test("Tickers already in the catalogue are not offered again")
    func heldTickersAreNotOffered() async throws {
        let existing = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)
        let importer = importer(FundQuoteFixtures.fmarketCatalogue)

        await importer.load(existing: [existing])

        #expect(importer.candidates.count == 3)
        #expect(importer.importable.map(\.symbol) == ["AEIF", "UMMF"])
    }

    @Test("Importing writes the chosen funds with their price and source")
    func importWritesChosenFunds() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let importer = importer(FundQuoteFixtures.fmarketCatalogue)
        await importer.load(existing: [])
        let stamped = Date(timeIntervalSince1970: 1_787_500_000)

        let added = try importer.importing(
            importer.importable,
            into: context,
            existing: [],
            createdAt: stamped
        )

        #expect(added == 3)

        let saved = try context.fetch(FetchDescriptor<FundInstrument>())
        let vesaf = try #require(saved.first { $0.symbol == "VESAF" })
        #expect(vesaf.currentPricePerUnit == Decimal(string: "31581.76"))
        #expect(vesaf.source == .fmarket)
        #expect(vesaf.priceFetchedAt == stamped)
        #expect(vesaf.autoQuoteEnabled)
        #expect(vesaf.currencyCode == "VND")

        // A fund the listing could not date is written at zero and left for
        // Refresh, rather than claiming a price nobody quoted.
        let aeif = try #require(saved.first { $0.symbol == "AEIF" })
        #expect(aeif.priceAsOf == Date(timeIntervalSince1970: 0))
    }

    @Test("Importing a ticker already stored adds nothing")
    func importingDuplicateAddsNothing() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let existing = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 25_000)
        context.insert(existing)
        try context.save()

        let importer = importer(FundQuoteFixtures.fmarketCatalogue)
        await importer.load(existing: [existing])

        let added = try importer.importing(
            importer.candidates,
            into: context,
            existing: [existing]
        )

        #expect(added == 2)
        let saved = try context.fetch(FetchDescriptor<FundInstrument>())
        #expect(saved.count == 3)
        // The stored price is untouched; the listing does not overwrite it.
        #expect(saved.first { $0.symbol == "VESAF" }?.currentPricePerUnit == 25_000)
    }

    @Test("Being offline is reported and writes nothing")
    func offlineIsReported() async throws {
        let importer = FundCatalogueImport(
            provider: FmarketQuoteProvider(transport: FailingTransport())
        )

        await importer.load(existing: [])

        #expect(importer.phase == .failed(.transport))
        #expect(importer.candidates.isEmpty)
        #expect(importer.phase.message == "No connection. Try again when you are back online.")
    }

    @Test("A changed reply is reported as a decoding failure")
    func changedReplyIsReported() async throws {
        let importer = importer("{\"status\":200,\"data\":{\"rows\":\"nope\"}}")

        await importer.load(existing: [])

        #expect(importer.phase == .failed(.decoding))
    }
}
