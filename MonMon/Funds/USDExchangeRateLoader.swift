import Foundation
import Observation

/// Fetches a starting USD/VND rate for a form that is about to need one.
///
/// It runs when the owner switches a price field to dollars and the rate box is
/// empty — never on opening a screen, never on a timer, and never over a rate
/// already stored. A saved position keeps the rate it was written with, because
/// that is the one that explains its cost; replacing it with today's would move
/// a purchase price that has not moved.
@MainActor
@Observable
final class USDExchangeRateLoader {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded(USDExchangeRate)
        case failed(FundQuoteError)
    }

    /// A second ask inside this window reuses what came back. In memory, so it
    /// resets on relaunch. Matches `FundPriceRefresher.requestFloor`.
    static let requestFloor: TimeInterval = 15 * 60

    private(set) var phase: Phase = .idle

    private let provider: CoinGeckoQuoteProvider
    private var lastAttempt: Date?

    init(provider: CoinGeckoQuoteProvider = CoinGeckoQuoteProvider()) {
        self.provider = provider
    }

    var rate: USDExchangeRate? {
        guard case .loaded(let rate) = phase else {
            return nil
        }
        return rate
    }

    var isLoading: Bool {
        phase == .loading
    }

    /// - Returns: the rate, when one arrived on this call or a recent one.
    @discardableResult
    func load(asOf: Date = .now) async -> USDExchangeRate? {
        if case .loading = phase {
            return nil
        }

        if let lastAttempt, asOf.timeIntervalSince(lastAttempt) < Self.requestFloor {
            // A failure inside the floor stays a failure: asking again straight
            // away would spend a request to be told the same thing.
            return rate
        }
        lastAttempt = asOf

        phase = .loading

        do {
            let rate = try await provider.usdExchangeRate()
            phase = .loaded(rate)
            return rate
        } catch let error as FundQuoteError {
            phase = .failed(error)
            return nil
        } catch {
            phase = .failed(.transport)
            return nil
        }
    }
}

extension USDExchangeRateLoader.Phase {
    /// What to say under the rate field. Nothing while idle: a box the owner
    /// can simply type into needs no explanation.
    func message(in locale: Locale) -> String? {
        switch self {
        case .idle:
            nil
        case .loading:
            AppText.string("Fetching today's rate…", in: locale)
        case .loaded:
            AppText.string("CoinGecko rate. Change it to the rate you paid.", in: locale)
        case .failed(.rateLimited):
            AppText.string("Checked a moment ago. Type the rate you paid.", in: locale)
        case .failed:
            AppText.string("Couldn’t fetch a rate. Type the rate you paid.", in: locale)
        }
    }
}
