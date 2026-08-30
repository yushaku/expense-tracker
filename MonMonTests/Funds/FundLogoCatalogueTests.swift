import Testing

@testable import MonMon

@Suite("Bundled fund logo catalogue")
struct FundLogoCatalogueTests {
    @Test("Open-ended funds and ETFs share their manager asset")
    func sharedManagerAsset() {
        #expect(FundLogoCatalogue.assetName(for: "DCDS") == "FundManagerDragonCapital")
        #expect(FundLogoCatalogue.assetName(for: "FUEVFVND") == "FundManagerDragonCapital")
        #expect(FundLogoCatalogue.assetName(for: "VEOF") == "FundManagerVinaCapital")
        #expect(FundLogoCatalogue.assetName(for: "FUEVN100") == "FundManagerVinaCapital")
        #expect(FundLogoCatalogue.assetName(for: "SSIBF") == "FundManagerSSIAM")
        #expect(FundLogoCatalogue.assetName(for: "FUESSVFL") == "FundManagerSSIAM")
    }

    @Test("Lookup normalizes user-entered symbols")
    func normalizedLookup() {
        #expect(
            FundLogoCatalogue.assetName(for: " fuevfvnd ") == "FundManagerDragonCapital"
        )
    }

    @Test("Unknown symbols retain the existing fallbacks")
    func unknownSymbol() {
        #expect(FundLogoCatalogue.assetName(for: "UNKNOWN") == nil)
    }
}
