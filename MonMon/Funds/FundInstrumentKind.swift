import Foundation
import SwiftUI

/// The behavior an asset kind contributes to shared forms and cards.
///
/// Screens consume capabilities from this value instead of branching on
/// `.gold`, `.crypto`, and every future kind themselves. Adding a new asset
/// therefore has one required mapping in `FundInstrumentKind.policy`.
struct FundInstrumentPolicy: Equatable, Sendable {
    struct Quantity: Equatable, Sendable {
        let displayedUnitsPerStoredUnit: Decimal
        let saleFieldTitleKey: String
        let holdingFieldTitleKey: String
        let accessibilityLabelKey: String
        let entryUnitLabelKey: String
        let metricTitle: String
        let soldMetricTitle: String
        let invalidEntryMessageKey: String
        let invalidHoldingMessageKey: String
        let nonPositiveHoldingMessageKey: String
        let usesGoldSummary: Bool

        static let units = Quantity(
            displayedUnitsPerStoredUnit: 1,
            saleFieldTitleKey: "Units to sell",
            holdingFieldTitleKey: "Units",
            accessibilityLabelKey: "Units",
            entryUnitLabelKey: "units",
            metricTitle: "UNITS",
            soldMetricTitle: "SOLD UNITS",
            invalidEntryMessageKey: "Enter a valid number of units.",
            invalidHoldingMessageKey: "Enter a valid number of units.",
            nonPositiveHoldingMessageKey: "Units must be greater than zero.",
            usesGoldSummary: false
        )

        static let goldWeight = Quantity(
            displayedUnitsPerStoredUnit: GoldWeight.chiPerLuong,
            saleFieldTitleKey: "Weight to sell",
            holdingFieldTitleKey: "Weight (chỉ)",
            accessibilityLabelKey: "Weight",
            entryUnitLabelKey: "chỉ",
            metricTitle: "WEIGHT",
            soldMetricTitle: "SOLD WEIGHT",
            invalidEntryMessageKey: "Enter a valid weight.",
            invalidHoldingMessageKey: "Enter a valid weight in chỉ.",
            nonPositiveHoldingMessageKey: "Weight must be greater than zero.",
            usesGoldSummary: true
        )

        var saleFieldTitle: LocalizedStringKey { LocalizedStringKey(saleFieldTitleKey) }
        var holdingFieldTitle: LocalizedStringKey { LocalizedStringKey(holdingFieldTitleKey) }
        var accessibilityLabel: LocalizedStringKey { LocalizedStringKey(accessibilityLabelKey) }
        var entryUnitLabel: LocalizedStringKey { LocalizedStringKey(entryUnitLabelKey) }
        var invalidEntryMessage: LocalizedStringKey {
            LocalizedStringKey(invalidEntryMessageKey)
        }
        var invalidHoldingMessage: LocalizedStringKey {
            LocalizedStringKey(invalidHoldingMessageKey)
        }
        var nonPositiveHoldingMessage: LocalizedStringKey {
            LocalizedStringKey(nonPositiveHoldingMessageKey)
        }

        func displayedUnits(fromStored units: Decimal) -> Decimal {
            units * displayedUnitsPerStoredUnit
        }

        func storedUnits(fromDisplayed units: Decimal) -> Decimal {
            units / displayedUnitsPerStoredUnit
        }

        func storedUnits(fromEntryText text: String) -> Decimal? {
            UnitQuantity.parse(text).map(storedUnits(fromDisplayed:))
        }

        func summaryValue(storedUnits: Decimal) -> String {
            usesGoldSummary
                ? GoldWeight.label(luong: storedUnits) : UnitQuantity.format(storedUnits)
        }

        func entryDescription(_ units: Decimal, locale: Locale) -> String {
            let value = UnitQuantity.format(units)
            let unit = AppText.string(key: entryUnitLabelKey, in: locale)
            return "\(value) \(unit)"
        }

        func saleDescription(storedUnits: Decimal, locale: Locale) -> String {
            usesGoldSummary
                ? GoldWeight.label(luong: storedUnits)
                : entryDescription(storedUnits, locale: locale)
        }
    }

    enum Fee: Equatable, Sendable {
        case shopDeduction
    }

    enum QuoteStyle: Equatable, Sendable {
        case averageCost
        case shopBuy
    }

    struct Editor: Equatable, Sendable {
        enum CatalogueRoute: Equatable, Sendable {
            case instrumentEditor
            case goldCatalogue
            case cryptoCatalogue
        }

        let catalogueRoute: CatalogueRoute
        let averageCostTitleKey: String
        let missingInstrumentMessageKey: String
        let emptyCatalogueMessageKey: String
        let addInstrumentTitleKey: String
        let introductionSymbol: String
        let introductionTitleKey: String
        let introductionDescriptionKey: String
        let newTitleKey: String
        let editTitleKey: String

        static let securities = Editor(
            catalogueRoute: .instrumentEditor,
            averageCostTitleKey: "Average cost per unit",
            missingInstrumentMessageKey: "Pick the fund or ETF this position is held in.",
            emptyCatalogueMessageKey: "No fund or ETF in the catalogue yet. Add one to hold it.",
            addInstrumentTitleKey: "Add instrument",
            introductionSymbol: "chart.line.uptrend.xyaxis",
            introductionTitleKey: "What you hold, what it is worth",
            introductionDescriptionKey: "Pick what you hold, then say how much of it you own.",
            newTitleKey: "Add holding",
            editTitleKey: "Edit holding"
        )

        static let gold = Editor(
            catalogueRoute: .goldCatalogue,
            averageCostTitleKey: "Average cost per lượng",
            missingInstrumentMessageKey: "Pick the gold product this position is held in.",
            emptyCatalogueMessageKey:
                "No gold product in the catalogue yet. Add one from vang.today.",
            addInstrumentTitleKey: "Add from vang.today",
            introductionSymbol: "seal.fill",
            introductionTitleKey: "The gold you hold",
            introductionDescriptionKey: "Pick a gold product, then enter its weight in chỉ.",
            newTitleKey: "Add gold",
            editTitleKey: "Edit gold"
        )

        static let crypto = Editor(
            catalogueRoute: .cryptoCatalogue,
            averageCostTitleKey: "Average cost per coin",
            missingInstrumentMessageKey: "Pick the coin this position is held in.",
            emptyCatalogueMessageKey: "No coin in the catalogue yet. Add one from CoinGecko.",
            addInstrumentTitleKey: "Add from CoinGecko",
            introductionSymbol: "bitcoinsign.circle.fill",
            introductionTitleKey: "The coins you hold",
            introductionDescriptionKey: "Pick a coin, then say how much of it you own.",
            newTitleKey: "Add coin",
            editTitleKey: "Edit coin"
        )
    }

    let quantity: Quantity
    let displayNameKey: String
    let allowsDollarPriceEntry: Bool
    let fee: Fee?
    let supportsSwap: Bool
    let quoteStyle: QuoteStyle
    /// What one unit of price is quoted against, in the owner's words. Not the
    /// same as the entry unit: gold is bought in chỉ and quoted per lượng, and
    /// a form that shows one without the other reads as a tenfold error.
    let priceUnitLabelKey: String
    let marketPriceLabelKey: String
    let instrumentPriceFieldTitleKey: String
    let salePriceTitleKey: String
    let priceMetricTitle: String
    let editor: Editor
    let editorKinds: [FundInstrumentKind]
}

/// What kind of asset an instrument is. The four cases price differently — an
/// open-ended fund by its published NAV, a listed ETF by its closing price, gold
/// by a shop's buy price, and a coin by a round-the-clock market — so this
/// decides which market-data provider runs.
enum FundInstrumentKind: String, Codable, CaseIterable, Sendable {
    case fund
    case etf
    case gold
    case crypto

    var policy: FundInstrumentPolicy {
        switch self {
        case .fund:
            FundInstrumentPolicy(
                quantity: .units,
                displayNameKey: "Fund",
                allowsDollarPriceEntry: false,
                fee: nil,
                supportsSwap: false,
                quoteStyle: .averageCost,
                priceUnitLabelKey: "unit",
                marketPriceLabelKey: "NAV",
                instrumentPriceFieldTitleKey: "NAV per unit",
                salePriceTitleKey: "Price per unit",
                priceMetricTitle: "NAV",
                editor: .securities,
                editorKinds: [.fund, .etf]
            )
        case .etf:
            FundInstrumentPolicy(
                quantity: .units,
                displayNameKey: "ETF",
                allowsDollarPriceEntry: false,
                fee: nil,
                supportsSwap: false,
                quoteStyle: .averageCost,
                priceUnitLabelKey: "unit",
                marketPriceLabelKey: "Close",
                instrumentPriceFieldTitleKey: "Market price per unit",
                salePriceTitleKey: "Price per unit",
                priceMetricTitle: "PRICE",
                editor: .securities,
                editorKinds: [.fund, .etf]
            )
        case .gold:
            FundInstrumentPolicy(
                quantity: .goldWeight,
                displayNameKey: "Gold",
                allowsDollarPriceEntry: false,
                fee: .shopDeduction,
                supportsSwap: false,
                quoteStyle: .shopBuy,
                priceUnitLabelKey: "lượng",
                marketPriceLabelKey: "Buy",
                instrumentPriceFieldTitleKey: "Shop buy price per lượng",
                salePriceTitleKey: "Price per lượng",
                priceMetricTitle: "BUY",
                editor: .gold,
                editorKinds: [.gold]
            )
        case .crypto:
            FundInstrumentPolicy(
                quantity: .units,
                displayNameKey: "Crypto",
                allowsDollarPriceEntry: true,
                fee: nil,
                supportsSwap: true,
                quoteStyle: .averageCost,
                priceUnitLabelKey: "coin",
                marketPriceLabelKey: "Price",
                instrumentPriceFieldTitleKey: "Market price per coin",
                salePriceTitleKey: "Price per coin",
                priceMetricTitle: "PRICE",
                editor: .crypto,
                editorKinds: [.crypto]
            )
        }
    }

    var displayNameKey: String {
        policy.displayNameKey
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
        policy.instrumentPriceFieldTitleKey
    }

    var priceLabel: LocalizedStringKey {
        LocalizedStringKey(priceLabelKey)
    }

    /// The kinds an editor opened on this one may choose between.
    ///
    /// A fund and an ETF share a picker because they are the same shape of
    /// thing: units bought through a broker, quoted per unit. Gold and coins do
    /// not join them. Each is entered differently — gold in chỉ, a coin to
    /// eight decimal places — and offering the others would let a position be
    /// repointed at something it is not.
    var editorKinds: [FundInstrumentKind] {
        policy.editorKinds
    }

    func priceLabel(in locale: Locale) -> String {
        AppText.string(key: priceLabelKey, in: locale)
    }
}
