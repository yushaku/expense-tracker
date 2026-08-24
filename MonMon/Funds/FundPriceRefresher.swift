import Foundation
import Observation
import SwiftData

/// Refreshes the catalogue's prices when the owner asks.
///
/// Owner-triggered only: no timer, no background task, no fetch on launch or on
/// a tab appearing. The app makes no connection nobody asked for.
@MainActor
@Observable
final class FundPriceRefresher {
    /// Why an instrument was left alone, or what happened to it.
    enum Outcome: Equatable {
        case updated(pricePerUnit: Decimal, asOf: Date)
        case unchanged(Skip)
        case failed(FundQuoteError)

        enum Skip: Equatable {
            /// Nothing is held in it. The catalogue may outlive a sold position,
            /// but a row nobody holds is not worth a request.
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
    private var lastAttempt: [String: Date] = [:]

    init(router: FundQuoteRouter = FundQuoteRouter()) {
        self.router = router
    }

    /// Instruments worth asking about at all: held by something, and not opted
    /// out. Used to disable Refresh rather than offer a button that does
    /// nothing.
    func hasAnythingToRefresh(instruments: [FundInstrument], holdings: [FundHolding]) -> Bool {
        instruments.contains { instrument in
            instrument.autoQuoteEnabled
                && !FundSummary.holdings(for: instrument, holdings: holdings).isEmpty
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
                asOf: asOf
            )
            outcomes[instrument.id] = outcome

            if case .updated = outcome {
                wroteAnything = true
            }
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

    private func refreshOne(
        _ instrument: FundInstrument,
        holdings: [FundHolding],
        asOf: Date
    ) async -> Outcome {
        guard instrument.autoQuoteEnabled else {
            return .unchanged(.automaticQuotesOff)
        }

        guard !FundSummary.holdings(for: instrument, holdings: holdings).isEmpty else {
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
