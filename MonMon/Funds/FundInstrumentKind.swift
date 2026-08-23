/// What kind of tradable thing an instrument is. The two cases price
/// differently — an open-ended fund by its published NAV, a listed ETF by its
/// closing price — so this is what decides which market-data provider runs.
///
/// The type keeps its original name. Renaming it looked free — the raw values
/// never change — but SwiftData hashes the attribute's Swift type name into the
/// schema, and a renamed enum makes an existing store unrecognisable to staged
/// migration ("Cannot use staged migration with an unknown model version").
/// `FundInstrumentKind` is an alias so new code can read the way the model does.
enum FundHoldingKind: String, Codable, CaseIterable, Sendable {
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

typealias FundInstrumentKind = FundHoldingKind
