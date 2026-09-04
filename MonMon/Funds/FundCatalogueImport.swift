import Foundation
import Observation
import SwiftData

/// Loads a provider's catalogue so the owner can pick entries instead of typing
/// a symbol, name, and price one at a time.
///
/// The list is fetched when the import screen is opened, and nothing is written
/// until something is chosen. Opening this screen is the ask.
@MainActor
@Observable
final class FundCatalogueImport {
    struct ImportFailure: Equatable, Sendable {
        let symbol: String
        let error: FundQuoteError
    }

    struct ImportResult: Equatable, Sendable {
        let addedSymbols: [String]
        let failures: [ImportFailure]

        var addedCount: Int { addedSymbols.count }
    }

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(FundQuoteError)
    }

    private(set) var phase: Phase = .idle
    private(set) var candidates: [FundInstrumentCandidate] = []
    /// Whether a remote lookup is in flight for the text being typed.
    private(set) var isSearchingRemotely = false
    /// Why the last remote lookup came back with nothing, when it failed.
    private(set) var remoteSearchFailure: FundQuoteError?
    /// Tickers already in the catalogue, so the list can mark them rather than
    /// offering a duplicate the draft would reject anyway.
    private(set) var alreadyHeld: Set<String> = []

    private let provider: any FundCatalogueProvider

    init(provider: any FundCatalogueProvider = FmarketQuoteProvider()) {
        self.provider = provider
    }

    var source: FundQuoteSource { provider.source }

    var importable: [FundInstrumentCandidate] {
        candidates.filter { !alreadyHeld.contains($0.symbol.uppercased()) }
    }

    /// The importable funds a search matches. Filtering happens here rather than
    /// through another request: the whole catalogue arrived in one call, so
    /// typing costs nothing.
    func matching(_ query: String) -> [FundInstrumentCandidate] {
        Self.filter(importable, matching: query)
    }

    /// Whether this provider's listing is a page rather than the whole list, so
    /// a search matching nothing locally is worth asking about.
    ///
    /// Only CoinGecko. Fmarket returns every open-ended fund and vang.today
    /// every gold product, so there is nothing beyond what already arrived;
    /// asking again would spend a request to be told the same thing.
    var offersRemoteSearch: Bool {
        provider.source == .coinGecko
    }

    /// The shortest query worth sending. One character matches thousands of
    /// coins and says nothing about which one is wanted.
    static let remoteSearchMinimumLength = 2

    /// Asks the provider for entries the loaded page does not carry, and folds
    /// what comes back into the list already on screen.
    ///
    /// Only when the local filter found nothing: the catalogue page holds the
    /// coins somebody is likely to be holding, and a query it answers needs no
    /// request. Results are merged rather than replacing the page, so ticking
    /// a found coin and then clearing the search does not lose it.
    func searchRemotely(_ query: String) async {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard offersRemoteSearch,
            wanted.count >= Self.remoteSearchMinimumLength,
            !isSearchingRemotely,
            matching(wanted).isEmpty
        else {
            return
        }

        isSearchingRemotely = true
        remoteSearchFailure = nil
        defer { isSearchingRemotely = false }

        do {
            merge(try await provider.search(wanted))
        } catch let error as FundQuoteError {
            remoteSearchFailure = error
        } catch {
            remoteSearchFailure = .transport
        }
    }

    /// Adds entries the list does not already carry, keyed by ticker because
    /// that is what `alreadyHeld` and the catalogue's own uniqueness rule use.
    private func merge(_ found: [FundInstrumentCandidate]) {
        var known = Set(candidates.map { $0.symbol.uppercased() })
        var merged = candidates

        for candidate in found where known.insert(candidate.symbol.uppercased()).inserted {
            merged.append(candidate)
        }

        guard merged.count != candidates.count else {
            return
        }

        candidates = merged.sorted { $0.symbol < $1.symbol }
    }

    /// Matches a ticker or any word of the name, ignoring case and accents.
    ///
    /// Fund names are Vietnamese and long — "QUỸ ĐẦU TƯ TRÁI PHIẾU AN BÌNH" —
    /// and nobody types the diacritics into a search field. `an binh` has to
    /// find it, so both sides are folded before comparing.
    static func filter(
        _ candidates: [FundInstrumentCandidate],
        matching query: String
    ) -> [FundInstrumentCandidate] {
        let needle = fold(query)
        guard !needle.isEmpty else {
            return candidates
        }

        return candidates.filter { candidate in
            fold(candidate.symbol).contains(needle)
                || fold(candidate.name).contains(needle)
                || fold(candidate.owner).contains(needle)
        }
    }

    /// One group per fund management company, each ordered by ticker, the groups
    /// themselves ordered by name.
    ///
    /// Funds from one manager tend to be considered together — somebody who
    /// holds VESAF is likelier to hold VEOF than something at random — so the
    /// list reads better grouped than as 67 rows in ticker order.
    struct OwnerGroup: Identifiable, Equatable {
        let owner: String
        let funds: [FundInstrumentCandidate]

        var id: String { owner }
    }

    static func grouped(_ candidates: [FundInstrumentCandidate]) -> [OwnerGroup] {
        Dictionary(grouping: candidates, by: \.displayOwner)
            .map { OwnerGroup(owner: $0.key, funds: $0.value.sorted { $0.symbol < $1.symbol }) }
            .sorted { lhs, rhs in
                // Anything the listing could not attribute sits at the end
                // rather than under "O" among real names.
                if (lhs.owner == "Other") != (rhs.owner == "Other") {
                    return rhs.owner == "Other"
                }
                return lhs.owner < rhs.owner
            }
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "vi_VN")
            )
    }

    func load(existing: [FundInstrument]) async {
        guard phase != .loading else {
            return
        }

        phase = .loading
        alreadyHeld = Set(existing.map { $0.symbol.uppercased() })

        do {
            candidates = try await provider.catalogue()
                .sorted { $0.symbol < $1.symbol }
            phase = .loaded
        } catch let error as FundQuoteError {
            candidates = []
            phase = .failed(error)
        } catch {
            candidates = []
            phase = .failed(.transport)
        }
    }

    /// Writes the chosen entries into the catalogue.
    ///
    /// A candidate the listing priced arrives already priced and sourced to
    /// Fmarket; one it did not is written at zero with automatic quotes on, so
    /// the next Refresh fills it in rather than the owner having to.
    ///
    /// ETF catalogue rows carry identity but no price. They are quoted in
    /// bounded batches before insertion, and a failed symbol is reported rather
    /// than written at zero. Other catalogue providers keep their listing data.
    @discardableResult
    func importing(
        _ chosen: [FundInstrumentCandidate],
        into context: ModelContext,
        existing: [FundInstrument],
        createdAt: Date = .now
    ) async throws -> ImportResult {
        var reservedSymbols = Set(existing.map { $0.symbol.uppercased() })
        var candidates: [FundInstrumentCandidate] = []

        for candidate in chosen {
            let symbol = candidate.symbol.uppercased()
            guard reservedSymbols.insert(symbol).inserted else {
                continue
            }
            candidates.append(candidate)
        }

        let resolved = await resolveETFQuotes(for: candidates, asOf: createdAt)
        var catalogue = existing
        var addedSymbols: [String] = []

        for candidate in resolved.candidates {
            let symbol = candidate.symbol.uppercased()
            guard catalogue.matching(symbol: symbol) == nil else {
                continue
            }

            let instrument = FundInstrument(
                id: UUID(),
                symbol: symbol,
                name: candidate.name,
                kind: candidate.kind,
                currentPricePerUnit: candidate.pricePerUnit ?? .zero,
                askPricePerUnit: candidate.askPricePerUnit ?? .zero,
                priceAsOf: candidate.priceAsOf ?? Date(timeIntervalSince1970: 0),
                priceSource: candidate.pricePerUnit == nil
                    ? FundQuoteSource.manual.rawValue
                    : provider.source.rawValue,
                priceFetchedAt: candidate.pricePerUnit == nil ? nil : createdAt,
                autoQuoteEnabled: true,
                logoURL: candidate.logoURL,
                providerID: candidate.providerID,
                currencyCode: VNDCurrency.code,
                createdAt: createdAt
            )
            context.insert(instrument)
            catalogue.append(instrument)
            addedSymbols.append(symbol)
        }

        if !addedSymbols.isEmpty {
            try context.save()
        }

        alreadyHeld.formUnion(addedSymbols)
        return ImportResult(addedSymbols: addedSymbols, failures: resolved.failures)
    }

    private static let maximumConcurrentQuotes = 4

    private enum QuoteOutcome: Sendable {
        case candidate(FundInstrumentCandidate)
        case failure(ImportFailure)
    }

    private struct QuoteAttempt: Sendable {
        let index: Int
        let outcome: QuoteOutcome
    }

    /// Providers whose listing carries identity but no price, so a chosen row
    /// has to be quoted before it can be written.
    ///
    /// VNDIRECT's ETF catalogue names tickers only. CoinGecko's search does the
    /// same for coins outside the catalogue page it returns priced. Everything
    /// else arrives priced by its listing.
    private static let unpricedListingSources: Set<FundQuoteSource> = [.vndirect, .coinGecko]

    private func resolveETFQuotes(
        for candidates: [FundInstrumentCandidate],
        asOf: Date
    ) async -> (candidates: [FundInstrumentCandidate], failures: [ImportFailure]) {
        guard Self.unpricedListingSources.contains(provider.source) else {
            return (candidates, [])
        }

        // A row the listing already priced is left alone; only the ones with
        // nothing to show are asked about.
        let priced = candidates.filter { $0.pricePerUnit != nil }
        let unpriced = candidates.filter { $0.pricePerUnit == nil }
        guard !unpriced.isEmpty else {
            return (candidates, [])
        }

        let indexed = Array(unpriced.enumerated())
        let quoteProvider = provider
        var attempts: [QuoteAttempt] = []

        for start in stride(
            from: 0,
            to: indexed.count,
            by: Self.maximumConcurrentQuotes
        ) {
            let end = min(start + Self.maximumConcurrentQuotes, indexed.count)
            await withTaskGroup(of: QuoteAttempt.self) { group in
                for (index, candidate) in indexed[start..<end] {
                    group.addTask {
                        do {
                            let quote = try await quoteProvider.latestQuote(
                                symbol: candidate.symbol,
                                providerID: candidate.providerID,
                                asOf: asOf
                            )
                            guard quote.symbol.uppercased() == candidate.symbol.uppercased() else {
                                return QuoteAttempt(
                                    index: index,
                                    outcome: .failure(
                                        ImportFailure(
                                            symbol: candidate.symbol,
                                            error: .decoding
                                        )
                                    )
                                )
                            }
                            return QuoteAttempt(
                                index: index,
                                outcome: .candidate(candidate.with(quote: quote))
                            )
                        } catch let error as FundQuoteError {
                            return QuoteAttempt(
                                index: index,
                                outcome: .failure(
                                    ImportFailure(symbol: candidate.symbol, error: error)
                                )
                            )
                        } catch {
                            return QuoteAttempt(
                                index: index,
                                outcome: .failure(
                                    ImportFailure(
                                        symbol: candidate.symbol,
                                        error: .transport
                                    )
                                )
                            )
                        }
                    }
                }

                for await attempt in group {
                    attempts.append(attempt)
                }
            }
        }

        attempts.sort { $0.index < $1.index }
        var quotedCandidates: [FundInstrumentCandidate] = []
        var failures: [ImportFailure] = []
        for attempt in attempts {
            switch attempt.outcome {
            case .candidate(let candidate):
                quotedCandidates.append(candidate)
            case .failure(let failure):
                failures.append(failure)
            }
        }
        // The order the owner ticked them in is not worth preserving here; the
        // catalogue is written sorted either way.
        return (priced + quotedCandidates, failures)
    }
}

private extension FundInstrumentCandidate {
    func with(quote: FundQuote) -> FundInstrumentCandidate {
        FundInstrumentCandidate(
            symbol: symbol,
            name: name,
            kind: kind,
            pricePerUnit: quote.pricePerUnit,
            askPricePerUnit: quote.askPricePerUnit,
            priceAsOf: quote.asOf,
            owner: owner,
            logoURL: logoURL,
            providerID: providerID
        )
    }
}

extension FundCatalogueImport.Phase {
    func message(providerName: String, in locale: Locale) -> String? {
        switch self {
        case .idle, .loading, .loaded:
            nil
        case .failed(.transport):
            AppText.string("No connection. Try again when you are back online.", in: locale)
        case .failed(.decoding):
            AppText.string(
                "\(providerName) changed its reply. Add the item by hand for now.",
                in: locale
            )
        case .failed(.symbolNotFound), .failed(.noQuoteAvailable):
            AppText.string("\(providerName) listed nothing.", in: locale)
        case .failed(.rateLimited):
            AppText.string("Checked a moment ago.", in: locale)
        }
    }
}
