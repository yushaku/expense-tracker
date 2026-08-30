import AppKit
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

    @Test("Every supported ETF has a bundled manager logo")
    func supportedETFs() {
        let symbols = [
            "E1VFVN30", "FUEABVND", "FUEBFVND", "FUEDCMID", "FUEFCV50", "FUEIP100",
            "FUEKIV30", "FUEKIVFS", "FUEKIVND", "FUEMAV30", "FUEMAVND", "FUEMITEC",
            "FUESSV30", "FUESSV50", "FUESSVFL", "FUETCC50", "FUETPVND", "FUEVFVND",
            "FUEVN100", "FUEVN50G",
        ]

        for symbol in symbols {
            #expect(FundLogoCatalogue.assetName(for: symbol) != nil, "Missing ETF: \(symbol)")
        }
    }

    @Test("Unknown symbols retain the existing fallbacks")
    func unknownSymbol() {
        #expect(FundLogoCatalogue.assetName(for: "UNKNOWN") == nil)
    }

    @Test("Every referenced logo is compiled into the asset catalogue")
    func bundledAssetsExist() {
        for assetName in FundLogoCatalogue.referencedAssetNames {
            #expect(NSImage(named: NSImage.Name(assetName)) != nil, "Missing asset: \(assetName)")
        }
    }
}
