import SwiftUI

/// What kind of asset an instrument is. The four cases price differently — an
/// open-ended fund by its published NAV, a listed ETF by its closing price, gold
/// by a shop's buy price, and a coin by a round-the-clock market — so this
/// decides which market-data provider runs.
enum FundInstrumentKind: String, Codable, CaseIterable, Sendable {
    case fund
    case etf
    case gold
    case crypto

    var displayNameKey: String {
        switch self {
        case .fund:
            "Fund"
        case .etf:
            "ETF"
        case .gold:
            "Gold"
        case .crypto:
            "Crypto"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: displayNameKey, in: locale)
    }

    /// What the price field is called for this kind. An open-ended fund quotes a
    /// NAV per unit; a listed ETF quotes a market price that sits at a premium
    /// or discount to its NAV. Calling both "NAV" would state something false
    /// about half the catalogue.
    var priceLabelKey: String {
        switch self {
        case .fund:
            "NAV per unit"
        case .etf:
            "Market price per unit"
        case .gold:
            "Shop buy price per lượng"
        case .crypto:
            "Market price per coin"
        }
    }

    var priceLabel: LocalizedStringKey {
        LocalizedStringKey(priceLabelKey)
    }

    func priceLabel(in locale: Locale) -> String {
        AppText.string(key: priceLabelKey, in: locale)
    }
}
