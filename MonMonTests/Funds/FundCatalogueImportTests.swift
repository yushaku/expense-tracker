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

    private func goldImporter() -> FundCatalogueImport {
        let transport = FixtureTransport([
            "api/prices": .init(FundQuoteFixtures.vangTodayCatalogue)
        ])
        return FundCatalogueImport(provider: VangTodayQuoteProvider(transport: transport))
    }

    @Test("The listing arrives priced, so importing costs one request")
    func listingArrivesPriced() async throws {
        let importer = importer(FundQuoteFixtures.fmarketCatalogue)

        await importer.load(existing: [])

        #expect(importer.phase == .loaded)
        #expect(importer.candidates.map(\.symbol) == ["AEIF", "UMMF", "VEOF", "VESAF"])

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

        #expect(importer.candidates.count == 4)
        #expect(importer.importable.map(\.symbol) == ["AEIF", "UMMF", "VEOF"])
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

        #expect(added == 4)

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

        #expect(added == 3)
        let saved = try context.fetch(FetchDescriptor<FundInstrument>())
        #expect(saved.count == 4)
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
        #expect(
            importer.phase.message(providerName: "Fmarket", in: Locale(identifier: "en"))
                == "No connection. Try again when you are back online."
        )
    }

    @Test("A changed reply is reported as a decoding failure")
    func changedReplyIsReported() async throws {
        let importer = importer("{\"status\":200,\"data\":{\"rows\":\"nope\"}}")

        await importer.load(existing: [])

        #expect(importer.phase == .failed(.decoding))
    }

    @Test("The gold catalogue excludes non-VND entries and groups by brand")
    func goldCatalogueGroupsVNDEntriesByBrand() async throws {
        let importer = goldImporter()

        await importer.load(existing: [])

        #expect(importer.candidates.map(\.symbol) == ["DOHCML", "SJL1L10"])
        #expect(FundCatalogueImport.grouped(importer.importable).map(\.owner) == ["DOJI", "SJC"])
    }

    @Test("An existing gold code is marked held and not offered again")
    func existingGoldIsNotOffered() async throws {
        let existing = FundTestFactory.instrument(
            symbol: "SJL1L10",
            kind: .gold,
            pricePerUnit: 147_000_000
        )
        let importer = goldImporter()

        await importer.load(existing: [existing])

        #expect(importer.alreadyHeld == ["SJL1L10"])
        #expect(importer.importable.map(\.symbol) == ["DOHCML"])
    }

    @Test("Importing gold keeps its kind, source, and two-sided price")
    func importingGoldKeepsProviderData() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let importer = goldImporter()
        await importer.load(existing: [])
        let stamped = Date(timeIntervalSince1970: 1_787_500_000)

        let added = try importer.importing(
            importer.importable,
            into: context,
            existing: [],
            createdAt: stamped
        )

        #expect(added == 2)
        let saved = try context.fetch(FetchDescriptor<FundInstrument>())
        let sjc = try #require(saved.first { $0.symbol == "SJL1L10" })
        #expect(sjc.kind == .gold)
        #expect(sjc.source == .vangToday)
        #expect(sjc.currentPricePerUnit == 147_000_000)
        #expect(sjc.askPricePerUnit == 150_000_000)
        #expect(sjc.priceFetchedAt == stamped)
    }
}

@Suite("Fund catalogue search and grouping")
@MainActor
struct FundCatalogueSearchTests {
    private func loaded() async -> FundCatalogueImport {
        let transport = FixtureTransport([
            "products/filter": .init(FundQuoteFixtures.fmarketCatalogue)
        ])
        let importer = FundCatalogueImport(
            provider: FmarketQuoteProvider(transport: transport)
        )
        await importer.load(existing: [])
        return importer
    }

    @Test("An empty search shows everything")
    func emptySearchShowsEverything() async {
        let importer = await loaded()

        #expect(importer.matching("").count == 4)
        #expect(importer.matching("   ").count == 4)
    }

    @Test("A ticker matches, whatever the case")
    func tickerMatches() async {
        let importer = await loaded()

        #expect(importer.matching("vesaf").map(\.symbol) == ["VESAF"])
        #expect(importer.matching("VESAF").map(\.symbol) == ["VESAF"])
    }

    /// Fund names carry every Vietnamese diacritic and nobody types them into a
    /// search field.
    @Test("A name matches without its accents")
    func nameMatchesWithoutAccents() async {
        let importer = await loaded()

        #expect(importer.matching("amber").map(\.symbol) == ["AEIF"])
        #expect(importer.matching("co phieu").count == 3)
        #expect(importer.matching("CỔ PHIẾU").count == 3)
    }

    @Test("A manager matches, so one search finds its whole family")
    func managerMatches() async {
        let importer = await loaded()

        #expect(importer.matching("vinacapital").map(\.symbol) == ["VEOF", "VESAF"])
    }

    @Test("Nothing matching yields nothing")
    func noMatchYieldsNothing() async {
        let importer = await loaded()

        #expect(importer.matching("zzz").isEmpty)
    }

    @Test("Funds are grouped under their manager, tickers ordered inside")
    func fundsAreGroupedByManager() async {
        let importer = await loaded()

        let groups = FundCatalogueImport.grouped(importer.importable)

        #expect(groups.map(\.owner) == ["UOB ASSET MANAGEMENT (VIỆT NAM)", "VINACAPITAL", "Other"])
        #expect(
            groups.first { $0.owner == "VINACAPITAL" }?.funds.map(\.symbol) == ["VEOF", "VESAF"])
    }

    /// The legal boilerplate is the same eight words on every manager; what
    /// tells them apart is the tail.
    @Test("The manager's legal boilerplate is trimmed off")
    func managerBoilerplateIsTrimmed() {
        func owner(_ text: String) -> String {
            FundInstrumentCandidate(symbol: "X", name: "X", kind: .fund, owner: text).displayOwner
        }

        #expect(owner("CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ VINACAPITAL") == "VINACAPITAL")
        #expect(owner("CÔNG TY TNHH QUẢN LÝ QUỸ SSI") == "SSI")
        #expect(
            owner("CÔNG TY TNHH QUẢN LÝ QUỸ ĐẦU TƯ CHỨNG KHOÁN VIETCOMBANK") == "VIETCOMBANK"
        )
        #expect(owner("CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ ĐẦU TƯ MB") == "MB")
        // Nothing to strip, and nothing at all.
        #expect(owner("DRAGON CAPITAL") == "DRAGON CAPITAL")
        #expect(owner("  ") == "Other")
    }

    /// A manager with no funds left to import must not leave an empty heading.
    @Test("Grouping an empty list yields no groups")
    func groupingEmptyYieldsNoGroups() {
        #expect(FundCatalogueImport.grouped([]).isEmpty)
    }
}
