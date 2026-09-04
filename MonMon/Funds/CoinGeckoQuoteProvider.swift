import Foundation

/// Coin prices from CoinGecko's public API.
///
/// Plain GET, no key and no account. Verified working on 2026-09-04.
///
/// CoinGecko quotes in whatever currency is asked for, so every request here
/// says `vnd` and nothing in this file converts anything. That is deliberate:
/// the app has no exchange rate and no place to keep one, and a price routed
/// through a USD figure would be two numbers' worth of error instead of one.
///
/// Coins are addressed by CoinGecko's own identifier — `bitcoin`, not `BTC` —
/// because tickers collide. Ten coins call themselves `BTC`, and asking by
/// ticker would price whichever one the endpoint happened to prefer. The
/// identifier travels as `FundInstrument.providerID`.
struct CoinGeckoQuoteProvider: FundCatalogueProvider {
    static let priceURL = URL.constant("https://api.coingecko.com/api/v3/simple/price")
    static let marketsURL = URL.constant("https://api.coingecko.com/api/v3/coins/markets")
    static let searchURL = URL.constant("https://api.coingecko.com/api/v3/search")

    /// The currency every request asks for, lowercased as the API wants it.
    static let quoteCurrency = "vnd"

    /// How many coins the catalogue offers. CoinGecko lists tens of thousands;
    /// the first page by market capitalisation is the part somebody is
    /// plausibly holding, and `search(_:)` reaches the rest.
    static let cataloguePageSize = 250

    let source = FundQuoteSource.coinGecko

    private let transport: any FundQuoteTransport

    init(transport: any FundQuoteTransport = URLSessionQuoteTransport()) {
        self.transport = transport
    }

    func latestQuote(symbol: String, providerID: String?, asOf: Date) async throws -> FundQuote {
        let identifier = Self.identifier(symbol: symbol, providerID: providerID)
        guard !identifier.isEmpty else {
            throw FundQuoteError.symbolNotFound
        }

        let payload = try JSONReader.object(try await json(priceRequest(identifier: identifier)))

        // An unknown identifier is answered with `{}` rather than an error, so
        // an empty reply means the coin is not there — not that the response
        // was malformed.
        guard let entry = payload[identifier] else {
            throw FundQuoteError.symbolNotFound
        }

        let quote = try JSONReader.object(entry)
        guard let raw = quote[Self.quoteCurrency] else {
            throw FundQuoteError.noQuoteAvailable
        }

        let price = try JSONReader.price(raw)
        // The stamp is when CoinGecko last moved the price, which for a market
        // that never closes is the only honest thing to call the quote's day.
        let asOfStamp = (try? JSONReader.int(quote["last_updated_at"])).map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }

        return FundQuote(
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            pricePerUnit: price,
            asOf: asOfStamp ?? asOf,
            source: source
        )
    }

    /// Coins CoinGecko knows by name or ticker, without prices.
    ///
    /// The search endpoint carries no figures, so a candidate from here is
    /// saved only after `latestQuote` returns one — the same rule the ETF
    /// import follows, and for the same reason: a row priced at zero is worse
    /// than a row that was never added.
    func search(_ query: String) async throws -> [FundInstrumentCandidate] {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else {
            return []
        }

        let payload = try JSONReader.object(try await json(searchRequest(query: wanted)))
        let rows = try JSONReader.array(payload["coins"])

        return try rows.compactMap { value in
            let row = try JSONReader.object(value)
            return try Self.candidate(
                id: row["id"],
                symbol: row["symbol"],
                name: row["name"],
                logo: row["large"] ?? row["thumb"]
            )
        }
    }

    /// The largest coins by market capitalisation, priced in one request.
    ///
    /// `coins/markets` returns the price alongside the name and the image, so
    /// importing a whole page costs one call rather than one per coin.
    func catalogue() async throws -> [FundInstrumentCandidate] {
        let rows = try JSONReader.array(try await json(marketsRequest()))

        return try rows.compactMap { value in
            let row = try JSONReader.object(value)
            guard
                var candidate = try Self.candidate(
                    id: row["id"],
                    symbol: row["symbol"],
                    name: row["name"],
                    logo: row["image"]
                )
            else {
                return nil
            }

            // A listing without a usable price is still worth offering; the
            // quote is fetched when it is chosen.
            let price = try? JSONReader.price(row["current_price"])
            let priceAsOf = (try? JSONReader.string(row["last_updated"]))
                .flatMap(Self.timestamp(from:))

            candidate = FundInstrumentCandidate(
                symbol: candidate.symbol,
                name: candidate.name,
                kind: .crypto,
                pricePerUnit: price,
                priceAsOf: price == nil ? nil : priceAsOf,
                owner: candidate.owner,
                logoURL: candidate.logoURL,
                providerID: candidate.providerID
            )
            return candidate
        }
    }

    /// Đồng per dollar, read off the stablecoin coins are actually bought with.
    ///
    /// Tether rather than a published FX rate, and not because it is a better
    /// dollar: it is the one a Vietnamese buyer hands over on an exchange, so
    /// its đồng price is nearer what a purchase really cost than an interbank
    /// mid would be. It is still only a starting value — the owner corrects it
    /// to whatever their desk gave them, and that corrected figure is what gets
    /// stored.
    static let dollarProxyID = "tether"

    func usdExchangeRate() async throws -> USDExchangeRate {
        let payload = try JSONReader.object(
            try await json(priceRequest(identifier: Self.dollarProxyID))
        )

        guard let entry = payload[Self.dollarProxyID] else {
            throw FundQuoteError.noQuoteAvailable
        }

        let quote = try JSONReader.object(entry)
        guard let raw = quote[Self.quoteCurrency] else {
            throw FundQuoteError.noQuoteAvailable
        }

        let asOfStamp = (try? JSONReader.int(quote["last_updated_at"])).map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }

        return USDExchangeRate(
            dongPerDollar: try JSONReader.price(raw),
            asOf: asOfStamp ?? Date(timeIntervalSince1970: 0)
        )
    }

    /// A GET whose rate-limit refusal keeps its own name.
    ///
    /// `FundQuoteTransport.json(_:)` folds every non-2xx reply into
    /// `.transport`, which would report a public-API throttle as "no
    /// connection". CoinGecko throttles an unauthenticated caller often enough
    /// that the difference is worth reading the status code for.
    private func json(_ request: URLRequest, retries: Int = 1) async throws -> Any {
        let (data, statusCode) = try await transport.send(request)

        if statusCode == 429 {
            throw FundQuoteError.rateLimited
        }

        guard (200..<300).contains(statusCode) else {
            guard retries > 0 else {
                throw FundQuoteError.transport
            }
            return try await json(request, retries: retries - 1)
        }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw FundQuoteError.decoding
        }
    }

    /// The provider's identifier, falling back to the lowercased ticker.
    ///
    /// The fallback is for a coin added by hand, where nobody chose an
    /// identifier. It is right often enough to be worth trying — `bitcoin` is
    /// not `btc`, but `pepe` is `pepe` — and a miss is reported as an unknown
    /// symbol rather than being priced as something else.
    static func identifier(symbol: String, providerID: String?) -> String {
        let stored = providerID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard stored.isEmpty else {
            return stored.lowercased()
        }

        return symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func candidate(
        id: Any?,
        symbol: Any?,
        name: Any?,
        logo: Any?
    ) throws -> FundInstrumentCandidate? {
        let identifier = try JSONReader.string(id)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let ticker = try JSONReader.string(symbol)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let title = try JSONReader.string(name)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !identifier.isEmpty, !ticker.isEmpty, !title.isEmpty else {
            return nil
        }

        return FundInstrumentCandidate(
            symbol: ticker,
            name: title,
            kind: .crypto,
            logoURL: try? JSONReader.string(logo),
            providerID: identifier
        )
    }

    private static func timestamp(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private func priceRequest(identifier: String) -> URLRequest {
        request(
            Self.priceURL.appending(queryItems: [
                URLQueryItem(name: "ids", value: identifier),
                URLQueryItem(name: "vs_currencies", value: Self.quoteCurrency),
                URLQueryItem(name: "include_last_updated_at", value: "true"),
            ]))
    }

    private func marketsRequest() -> URLRequest {
        request(
            Self.marketsURL.appending(queryItems: [
                URLQueryItem(name: "vs_currency", value: Self.quoteCurrency),
                URLQueryItem(name: "order", value: "market_cap_desc"),
                URLQueryItem(name: "per_page", value: String(Self.cataloguePageSize)),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "sparkline", value: "false"),
            ]))
    }

    private func searchRequest(query: String) -> URLRequest {
        request(
            Self.searchURL.appending(queryItems: [
                URLQueryItem(name: "query", value: query)
            ]))
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
