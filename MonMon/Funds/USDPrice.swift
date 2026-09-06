import Foundation
import SwiftUI

/// Which currency a price was typed in.
///
/// Only the entry changes. What is stored is đồng either way, because every
/// balance, cost basis and profit figure in this app is đồng, and a second
/// currency in the store would mean every one of them had to ask which.
enum PriceEntryCurrency: String, CaseIterable, Identifiable, Sendable {
    case vnd
    case usd

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .vnd:
            "₫"
        case .usd:
            "$"
        }
    }

    var displayNameKey: String {
        switch self {
        case .vnd:
            "Đồng"
        case .usd:
            "Dollar"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameKey)
    }
}

/// Dollars, and the rate that turns them into đồng.
///
/// Coins are bought in dollars and this app counts in đồng, so somewhere the
/// two have to meet. They meet here, once, at the moment a position is written
/// — never at valuation, and never at a screen that shows a total. A rate that
/// applied at a later read would make last year's purchase price move with
/// today's dollar, which is not what the owner paid.
///
/// The rate is the owner's, not a market's. Coins are usually bought through an
/// exchange or a P2P desk whose rate is not the published one, and the figure
/// that has to end up in the store is the đồng that actually left the account.
/// A fetched rate is therefore a starting value to correct, not an answer.
enum USDPrice {
    /// Eight, matching `UnitQuantity`: a coin's dollar price can be a very
    /// small number, and rounding a memecoin's price to cents would store zero.
    static let maximumFractionDigits = 8

    private static let locale = Locale(identifier: "vi_VN")
    private static let displayFormat = Decimal.FormatStyle(locale: locale)
        .precision(.fractionLength(0...maximumFractionDigits))
        .grouping(.never)

    /// Accepts the same shapes `UnitQuantity` does — a decimal comma or a
    /// decimal dot, no grouping — because the two fields sit next to each other
    /// on the same form and typing one differently from the other would be a
    /// trap rather than a feature.
    static func parse(_ text: String) -> Decimal? {
        guard let value = UnitQuantity.parse(text) else {
            return nil
        }
        return value
    }

    static func format(_ amount: Decimal) -> String {
        displayFormat.format(amount)
    }

    /// Đồng for a dollar amount at a stated rate.
    ///
    /// Deliberately not rounded. This is a price for one unit, not a balance:
    /// a coin worth a thousandth of a đồng rounds to nothing, and a position in
    /// it would then fail validation for a cost of zero. `FundValuation` still
    /// rounds where it matters — the amount deducted from the funding account.
    static func inDong(_ dollars: Decimal, rate: Decimal) -> Decimal? {
        guard dollars > 0, rate > 0 else {
            return nil
        }
        return dollars * rate
    }

    /// The dollar figure that produced a đồng price at a stated rate, so
    /// reopening an editor shows what was typed rather than the conversion.
    static func inDollars(_ dong: Decimal, rate: Decimal) -> Decimal? {
        guard dong > 0, rate > 0 else {
            return nil
        }
        return dong / rate
    }
}

/// One USD/VND rate and when it was published.
struct USDExchangeRate: Sendable, Equatable {
    /// Đồng per dollar.
    let dongPerDollar: Decimal
    /// When the provider last moved it, not when the app asked.
    let asOf: Date
}
