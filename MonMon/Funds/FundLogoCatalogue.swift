import Foundation

enum FundLogoCatalogue {
    static func assetName(for symbol: String) -> String? {
        assetsBySymbol[normalized(symbol)]
    }

    static let referencedAssetNames = Set(managerSymbols.map(\.assetName))

    private static let assetsBySymbol: [String: String] = managerSymbols.reduce(into: [:]) {
        result,
        manager in
        for symbol in manager.symbols {
            result[normalized(symbol)] = manager.assetName
        }
    }

    private static let managerSymbols: [(assetName: String, symbols: [String])] = [
        ("FundManagerABF", ["ABBF", "ABEF", "FUEABVND"]),
        ("FundManagerAmber", ["AEIF", "ASBF"]),
        ("FundManagerBaoViet", ["BVBF", "BVFED", "BVPF", "FUEBFVND"]),
        (
            "FundManagerDragonCapital",
            ["DCBF", "DCDE", "DCDS", "DCIP", "E1VFVN30", "FUEDCMID", "FUEVFVND"]
        ),
        ("FundManagerDaiIchi", ["DCAF", "DFIX"]),
        ("FundManagerEastspring", ["ENF", "EVESG"]),
        ("FundManagerHDCapital", ["GDEGF", "HDBOND"]),
        ("FundManagerIPAPartner", ["VNDAF", "VNDBF", "VNDCF", "FUEIP100"]),
        ("FundManagerKIM", ["KDEF", "KSIF", "FUEKIV30", "FUEKIVFS", "FUEKIVND"]),
        ("FundManagerLighthouse", ["LHBF", "LHCDF", "LHFCF"]),
        ("FundManagerLPB", ["LPBF", "LPLF"]),
        ("FundManagerManulife", ["MAFBAL", "MAFEQI", "MDI"]),
        ("FundManagerMBCapital", ["BMFF", "MBAM", "MBBOND", "MBVF"]),
        ("FundManagerMiraeAsset", ["MAFF", "MAGEF", "FUEMAV30", "FUEMAVND"]),
        ("FundManagerNTP", ["NTPPF"]),
        ("FundManagerPhuHung", ["PHVSF"]),
        ("FundManagerPVCB", ["PBIF", "PVBF"]),
        ("FundManagerSGI", ["TBLF"]),
        (
            "FundManagerSSIAM",
            ["SSI-EF", "SSI-PDF", "SSIBF", "SSISCA", "VLGF", "FUESSV30", "FUESSV50", "FUESSVFL"]
        ),
        ("FundManagerTechcomCapital", ["TCGF", "FUETCC50"]),
        ("FundManagerUOB", ["UMMF", "USIF", "UVDIF", "UVEEF"]),
        ("FundManagerVietCapital", ["VCAMBF", "VCAMDF", "VCAMFI"]),
        ("FundManagerRongViet", ["RVPIF"]),
        ("FundManagerVCBF", ["VCBF-AIF", "VCBF-BCF", "VCBF-FIF", "VCBF-MGF", "VCBF-TBF"]),
        ("FundManagerVietinBank", ["VBIF"]),
        (
            "FundManagerVinaCapital",
            [
                "VDEF", "VEOF", "VESAF", "VFF", "VIBF", "VLBF", "VMEEF", "FUEVN50G",
                "FUEVN100", "FUEMITEC",
            ]
        ),
        ("FundManagerFPTCapital", ["FUEFCV50"]),
        ("FundManagerVFC", ["FUETPVND"]),
    ]

    private static func normalized(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
