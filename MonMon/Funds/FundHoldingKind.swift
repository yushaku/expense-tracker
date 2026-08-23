enum FundHoldingKind: String, Codable, CaseIterable {
    case fund
    case etf

    var displayName: String {
        switch self {
        case .fund:
            "Fund"
        case .etf:
            "ETF"
        }
    }
}
