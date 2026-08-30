import SwiftUI

/// Where an instrument's current price came from.
///
/// Persisted as a raw `String` on `FundInstrument`, so a later provider can be
/// added without a migration and an unknown value read back by an older build
/// degrades to `.manual` rather than failing to decode.
enum FundQuoteSource: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Typed by the owner. Also what every price is after the migration from a
    /// store that predates market data.
    case manual
    /// Open-ended fund NAV, published at T+1.
    case fmarket
    /// Closing price of an ETF listed on HOSE.
    case vndirect
    /// Shop buy and sell prices for physical gold.
    case vangToday

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .manual:
            "Entered by hand"
        case .fmarket:
            "Fmarket"
        case .vndirect:
            "VNDIRECT"
        case .vangToday:
            "vang.today"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: displayNameKey, in: locale)
    }
}
