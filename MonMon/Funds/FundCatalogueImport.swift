import Foundation
import Observation
import SwiftData

/// Loads Fmarket's list of open-ended funds so the owner can pick from it
/// instead of typing a ticker, a name and a price per fund.
///
/// Owner-triggered, like every other outbound call in the app: the list is
/// fetched when the import screen is opened, and nothing is written until
/// something is chosen.
@MainActor
@Observable
final class FundCatalogueImport {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(FundQuoteError)
    }

    private(set) var phase: Phase = .idle
    private(set) var candidates: [FundInstrumentCandidate] = []
    /// Tickers already in the catalogue, so the list can mark them rather than
    /// offering a duplicate the draft would reject anyway.
    private(set) var alreadyHeld: Set<String> = []

    private let provider: FmarketQuoteProvider

    init(provider: FmarketQuoteProvider = FmarketQuoteProvider()) {
        self.provider = provider
    }

    var importable: [FundInstrumentCandidate] {
        candidates.filter { !alreadyHeld.contains($0.symbol.uppercased()) }
    }

    /// The importable funds a search matches. Filtering happens here rather than
    /// through another request: the whole catalogue arrived in one call, so
    /// typing costs nothing.
    func matching(_ query: String) -> [FundInstrumentCandidate] {
        Self.filter(importable, matching: query)
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

    /// Writes the chosen funds into the catalogue.
    ///
    /// A candidate the listing priced arrives already priced and sourced to
    /// Fmarket; one it did not is written at zero with automatic quotes on, so
    /// the next Refresh fills it in rather than the owner having to.
    ///
    /// - Returns: how many were added.
    @discardableResult
    func importing(
        _ chosen: [FundInstrumentCandidate],
        into context: ModelContext,
        existing: [FundInstrument],
        createdAt: Date = .now
    ) throws -> Int {
        var catalogue = existing
        var added = 0

        for candidate in chosen {
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
                priceAsOf: candidate.priceAsOf ?? Date(timeIntervalSince1970: 0),
                priceSource: candidate.pricePerUnit == nil
                    ? FundQuoteSource.manual.rawValue
                    : FundQuoteSource.fmarket.rawValue,
                priceFetchedAt: candidate.pricePerUnit == nil ? nil : createdAt,
                autoQuoteEnabled: true,
                currencyCode: VNDCurrency.code,
                createdAt: createdAt
            )
            context.insert(instrument)
            catalogue.append(instrument)
            added += 1
        }

        if added > 0 {
            try context.save()
        }

        alreadyHeld.formUnion(chosen.map { $0.symbol.uppercased() })
        return added
    }
}

extension FundCatalogueImport.Phase {
    var message: String? {
        switch self {
        case .idle, .loading, .loaded:
            nil
        case .failed(.transport):
            "No connection. Try again when you are back online."
        case .failed(.decoding):
            "Fmarket changed its reply. Add the fund by hand for now."
        case .failed(.symbolNotFound), .failed(.noQuoteAvailable):
            "Fmarket listed nothing."
        case .failed(.rateLimited):
            "Checked a moment ago."
        }
    }
}
