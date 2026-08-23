/// What kind of tradable thing an instrument is. The two cases price
/// differently — an open-ended fund by its published NAV, a listed ETF by its
/// closing price — so this is what decides which market-data provider runs.
enum FundInstrumentKind: String, Codable, CaseIterable, Sendable {
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

    /// What the price field is called for this kind. An open-ended fund quotes a
    /// NAV per unit; a listed ETF quotes a market price that sits at a premium
    /// or discount to its NAV. Calling both "NAV" would state something false
    /// about half the catalogue.
    var priceLabel: String {
        switch self {
        case .fund:
            "NAV per unit"
        case .etf:
            "Market price per unit"
        }
    }
}
