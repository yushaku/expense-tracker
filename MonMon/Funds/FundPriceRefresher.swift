import Foundation
import Observation
import SwiftData

/// Refreshes the catalogue's prices, on the owner's word or on opening a screen
/// that shows a price too old to be right.
///
/// There is still no timer and no background task: the app fetches while the
/// owner is looking at the figure it would correct, and never otherwise. What
/// bounds it is `requestFloor` and staleness — a screen opened twice in a
/// minute, or opened onto prices already current, asks for nothing.
@MainActor
@Observable
final class FundPriceRefresher {
    /// Why an instrument was left alone, or what happened to it.
    enum Outcome: Equatable {
        case updated(pricePerUnit: Decimal, asOf: Date)
        case unchanged(Skip)
        case failed(FundQuoteError)

        enum Skip: Equatable {
            /// Nothing is held in it. The catalogue may outlive a sold
            /// position, but a row nobody holds is not worth a request — and a
            /// position that has been closed is one nobody holds, however many
            /// records of it remain.
            case notHeld
            /// The owner switched automatic quotes off for this ticker.
            case automaticQuotesOff
            /// Already priced at the newest day it could possibly cover.
            case alreadyCurrent
            /// Asked again inside the floor below.
            case askedTooRecently
        }
    }

    /// A second Refresh inside this window reuses what is stored rather than
    /// calling out again. In memory, so it resets on relaunch.
    static let requestFloor: TimeInterval = 15 * 60

    private(set) var isRunning = false
    /// Keyed by instrument id, from the most recent refresh.
    private(set) var outcomes: [UUID: Outcome] = [:]

    private let router: FundQuoteRouter
    /// Where a missing logo is looked up. Fmarket lists every fund's manager
    /// and that manager's image in one reply, so a backfill costs one request
    /// however many instruments are short of one.
    private let catalogue: any FundCatalogueProvider
    private var lastAttempt: [String: Date] = [:]
    private var lastLogoAttempt: Date?

    init(
        router: FundQuoteRouter = FundQuoteRouter(),
        catalogue: any FundCatalogueProvider = FmarketQuoteProvider()
    ) {
        self.router = router
        self.catalogue = catalogue
    }

    /// Whether opening a screen should fetch without being asked: something is
    /// held, its quotes are automatic, and the price on it is older than the
    /// newest day it could carry.
    ///
    /// Separate from `hasAnythingToRefresh` because the two answer different
    /// questions. The button stays offered while every price is current — the
    /// owner may know something the calendar does not — but a screen opening
    /// onto current prices must ask for nothing.
    func hasAnythingStale(
        instruments: [FundInstrument],
        holdings: [FundHolding],
        sales: [FundSale],
        asOf: Date = .now
    ) -> Bool {
        instruments.contains { instrument in
            instrument.autoQuoteEnabled
                && TradingCalendar.isStale(
                    priceAsOf: instrument.priceAsOf,
                    kind: instrument.kind,
                    asOf: asOf
                )
                && FundSummary.totalUnits(
                    for: instrument,
                    holdings: holdings,
                    sales: sales
                ) > 0
        }
    }

    /// Instruments worth asking about at all: held by something, and not opted
    /// out. Used to disable Refresh rather than offer a button that does
    /// nothing.
    func hasAnythingToRefresh(
        instruments: [FundInstrument],
        holdings: [FundHolding],
        sales: [FundSale]
    ) -> Bool {
        instruments.contains { instrument in
            instrument.autoQuoteEnabled
                && FundSummary.totalUnits(
                    for: instrument,
                    holdings: holdings,
                    sales: sales
                ) > 0
        }
    }

    /// Fetches each instrument in turn and writes what came back.
    ///
    /// Sequential rather than concurrent: a catalogue holds a handful of
    /// tickers, and a parallel burst buys nothing while looking like abuse.
    /// One ticker failing never stops the rest, and a failure writes nothing at
    /// all — the previous price, its day, its source and its fetch time all
    /// stand, because a stale figure the owner can see is better than a hole.
    func refresh(
        instruments: [FundInstrument],
        holdings: [FundHolding],
        sales: [FundSale],
        in context: ModelContext,
        asOf: Date = .now
    ) async {
        guard !isRunning else {
            return
        }

        isRunning = true
        outcomes = [:]
        defer { isRunning = false }

        var wroteAnything = false

        for instrument in instruments {
            let outcome = await refreshOne(
                instrument,
                holdings: holdings,
                sales: sales,
                asOf: asOf
            )
            outcomes[instrument.id] = outcome

            if case .updated = outcome {
                wroteAnything = true
            }
        }

        // The logos come last and separately: a fund's image is not its price,
        // and a listing that will not answer must not cost the prices already
        // fetched above.
        if await syncLogos(instruments: instruments, asOf: asOf) {
            wroteAnything = true
        }

        guard wroteAnything else {
            return
        }

        do {
            try context.save()
        } catch {
            // Rolling back drops the fetched prices, which is the honest
            // outcome: nothing was persisted, so nothing should be on screen
            // claiming it was.
            context.rollback()
            for (id, outcome) in outcomes where outcome.isUpdate {
                outcomes[id] = .failed(.transport)
            }
        }
    }

    /// The same refresh, but only when a price on show is out of date.
    ///
    /// This is what a screen calls on opening. It returns without a request
    /// when everything is current, so arriving at a screen twice in a row is
    /// silent rather than a spinner over figures that were already right.
    func refreshStale(
        instruments: [FundInstrument],
        holdings: [FundHolding],
        sales: [FundSale],
        in context: ModelContext,
        asOf: Date = .now
    ) async {
        guard
            hasAnythingStale(
                instruments: instruments,
                holdings: holdings,
                sales: sales,
                asOf: asOf
            )
        else {
            return
        }

        await refresh(
            instruments: instruments,
            holdings: holdings,
            sales: sales,
            in: context,
            asOf: asOf
        )
    }

    /// Fills in the manager's logo for funds imported before there were logos,
    /// or added by hand under a ticker Fmarket lists.
    ///
    /// Missing ones only. A logo already stored is left exactly as it is: the
    /// image is decoration, and re-reading the whole catalogue to rewrite a URL
    /// that still resolves would spend a request on nothing.
    ///
    /// - Returns: whether anything was written.
    private func syncLogos(instruments: [FundInstrument], asOf: Date) async -> Bool {
        let missing = instruments.filter { $0.logoURL == nil && $0.kind != .gold }
        guard !missing.isEmpty else {
            return false
        }

        if let last = lastLogoAttempt, asOf.timeIntervalSince(last) < Self.requestFloor {
            return false
        }
        lastLogoAttempt = asOf

        guard let listed = try? await catalogue.catalogue() else {
            // A logo nobody can fetch is not worth reporting. The badge already
            // says the only thing there is to say by showing the ticker.
            return false
        }

        let logos = Dictionary(
            listed.compactMap { candidate -> (String, String)? in
                candidate.logoURL.map { (candidate.symbol.uppercased(), $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        var wrote = false
        for instrument in missing {
            guard let logo = logos[instrument.symbol.uppercased()] else {
                continue
            }
            instrument.logoURL = logo
            wrote = true
        }
        return wrote
    }

    private func refreshOne(
        _ instrument: FundInstrument,
        holdings: [FundHolding],
        sales: [FundSale],
        asOf: Date
    ) async -> Outcome {
        guard instrument.autoQuoteEnabled else {
            return .unchanged(.automaticQuotesOff)
        }

        guard FundSummary.totalUnits(for: instrument, holdings: holdings, sales: sales) > 0
        else {
            return .unchanged(.notHeld)
        }

        guard
            TradingCalendar.isStale(
                priceAsOf: instrument.priceAsOf,
                kind: instrument.kind,
                asOf: asOf
            )
        else {
            return .unchanged(.alreadyCurrent)
        }

        let ticker = instrument.symbol.uppercased()
        if let last = lastAttempt[ticker], asOf.timeIntervalSince(last) < Self.requestFloor {
            return .unchanged(.askedTooRecently)
        }
        lastAttempt[ticker] = asOf

        do {
            let quote = try await router.latestQuote(
                symbol: ticker,
                kind: instrument.kind,
                asOf: asOf
            )

            instrument.currentPricePerUnit = quote.pricePerUnit
            instrument.askPricePerUnit = quote.askPricePerUnit ?? .zero
            instrument.priceAsOf = quote.asOf
            instrument.priceSource = quote.source.rawValue
            instrument.priceFetchedAt = asOf

            return .updated(pricePerUnit: quote.pricePerUnit, asOf: quote.asOf)
        } catch let error as FundQuoteError {
            return .failed(error)
        } catch {
            return .failed(.transport)
        }
    }
}

extension FundPriceRefresher.Outcome {
    var isUpdate: Bool {
        if case .updated = self {
            return true
        }
        return false
    }

    /// What to put on the card. `nil` where there is nothing worth saying — a
    /// row nobody holds, or one already current, needs no explanation.
    func message(in locale: Locale) -> String? {
        switch self {
        case .updated:
            AppText.string("Updated", in: locale)
        case .unchanged(.automaticQuotesOff), .unchanged(.notHeld), .unchanged(.alreadyCurrent):
            nil
        case .unchanged(.askedTooRecently):
            AppText.string("Checked a moment ago", in: locale)
        case .failed(.symbolNotFound):
            AppText.string("Symbol not found", in: locale)
        case .failed(.noQuoteAvailable):
            AppText.string("No price published", in: locale)
        case .failed(.transport):
            AppText.string("No connection", in: locale)
        case .failed(.decoding):
            AppText.string("The provider changed its reply", in: locale)
        case .failed(.rateLimited):
            AppText.string("Checked a moment ago", in: locale)
        }
    }

    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
