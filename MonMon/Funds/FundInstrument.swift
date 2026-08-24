import Foundation
import SwiftData

/// One fund, ETF, or gold product, and the price every position in it is valued at.
///
/// The price lives here rather than on `FundHolding` because it is a property
/// of the instrument, not of a position. With it on the holding, two rows for
/// one ticker could carry two prices at the same moment and net worth would be
/// wrong with nothing to show for it.
@Model
final class FundInstrument {
    var id: UUID = UUID()
    /// Uppercased ticker, e.g. `FUEVFVND`. Unique across the catalogue, enforced
    /// in `FundInstrumentDraft` rather than with `@Attribute(.unique)`: CloudKit
    /// forbids unique attributes, and `icloud-sync` should inherit no schema
    /// debt from here.
    var symbol: String = ""
    var name: String = ""
    var kind: FundInstrumentKind = FundInstrumentKind.fund
    /// The price the owner receives for one unit. For funds and ETFs this is the
    /// only price; for gold it is the shop's buy side.
    var currentPricePerUnit: Decimal = Decimal.zero
    /// The price the shop charges for one unit of gold. Zero for funds, ETFs,
    /// and gold products that have not fetched a two-sided quote.
    var askPricePerUnit: Decimal = Decimal.zero
    /// The trading day this price belongs to — not when it was fetched.
    /// Asking on a Sunday returns Friday's figure, and conflating the two would
    /// report a weekend price that never existed.
    var priceAsOf: Date = Date(timeIntervalSince1970: 0)
    /// `FundQuoteSource` raw value, stored as a `String` for the same reason
    /// `kind` is: a new source can arrive without a migration.
    var priceSource: String = FundQuoteSource.manual.rawValue
    /// When the app last fetched successfully. `nil` while the price is typed.
    var priceFetchedAt: Date?
    var autoQuoteEnabled: Bool = true
    var currencyCode: String = VNDCurrency.code
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        symbol: String,
        name: String,
        kind: FundInstrumentKind,
        currentPricePerUnit: Decimal,
        askPricePerUnit: Decimal = .zero,
        priceAsOf: Date,
        priceSource: String = FundQuoteSource.manual.rawValue,
        priceFetchedAt: Date? = nil,
        autoQuoteEnabled: Bool = true,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.kind = kind
        self.currentPricePerUnit = currentPricePerUnit
        self.askPricePerUnit = askPricePerUnit
        self.priceAsOf = priceAsOf
        self.priceSource = priceSource
        self.priceFetchedAt = priceFetchedAt
        self.autoQuoteEnabled = autoQuoteEnabled
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

extension FundInstrument {
    /// The stored source, or `.manual` when the raw value is one this build does
    /// not know. An unreadable source must not stop a price from rendering.
    var source: FundQuoteSource {
        FundQuoteSource(rawValue: priceSource) ?? .manual
    }

    /// How this instrument's price should be described in a sentence:
    /// "NAV 21 Aug 2026 · Fmarket", or "Entered by hand".
    var priceLabel: String {
        switch kind {
        case .fund:
            "NAV"
        case .etf:
            "Close"
        case .gold:
            "Buy"
        }
    }
}

extension Array where Element == FundInstrument {
    /// The instrument a holding points at, or `nil` when nothing does. Joins are
    /// resolved in Swift because the schema carries no SwiftData relationships;
    /// a dangling `instrumentID` is therefore representable and every caller has
    /// to decide what to show for it.
    func matching(_ holding: FundHolding) -> FundInstrument? {
        first { $0.id == holding.instrumentID }
    }

    func matching(symbol: String) -> FundInstrument? {
        let wanted = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return first { $0.symbol.uppercased() == wanted }
    }
}
