import Foundation

/// Closing price for ETFs listed on HOSE, from VNDIRECT's chart API.
///
/// A TradingView UDF endpoint: plain GET, no authentication, no service level
/// and no licence to reuse the data. Verified working on 2026-08-21.
struct VNDirectQuoteProvider: FundCatalogueProvider {
    static let historyURL = URL.constant("https://dchart-api.vndirect.com.vn/dchart/history")
    static let symbolsURL = URL.constant("https://dchart-api.vndirect.com.vn/dchart/symbols")
    static let searchURL = URL.constant("https://dchart-api.vndirect.com.vn/dchart/search")

    /// Closes are quoted in thousands of đồng: `34.2` is 34,200 ₫.
    static let priceScale: Decimal = 1_000

    /// How far back to ask. A symbol suspended for a fortnight still yields its
    /// last close.
    static let lookbackDays = 30

    let source = FundQuoteSource.vndirect

    private let transport: any FundQuoteTransport

    init(transport: any FundQuoteTransport = URLSessionQuoteTransport()) {
        self.transport = transport
    }

    func latestQuote(symbol: String, providerID: String?, asOf: Date) async throws -> FundQuote {
        let wanted = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let value = try await transport.json(historyRequest(symbol: wanted, asOf: asOf))
        let payload = try JSONReader.object(value)

        // `s` is "ok" on success. "no_data" and anything else mean there is
        // nothing to read, which is not the same as a broken response.
        let status = try JSONReader.string(payload["s"])
        guard status == "ok" else {
            throw FundQuoteError.noQuoteAvailable
        }

        let closes = try JSONReader.array(payload["c"])
        let stamps = try JSONReader.array(payload["t"])
        guard closes.count == stamps.count else {
            throw FundQuoteError.decoding
        }
        guard let close = closes.last, let stamp = stamps.last else {
            throw FundQuoteError.noQuoteAvailable
        }

        let price = try JSONReader.price(close) * Self.priceScale
        let day = TradingCalendar.calendar.startOfDay(
            for: Date(timeIntervalSince1970: TimeInterval(try JSONReader.int(stamp)))
        )

        return FundQuote(symbol: wanted, pricePerUnit: price, asOf: day, source: source)
    }

    func search(_ query: String) async throws -> [FundInstrumentCandidate] {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !wanted.isEmpty else {
            return []
        }

        var request = URLRequest(
            url: Self.symbolsURL.appending(
                queryItems: [URLQueryItem(name: "symbol", value: wanted)]
            ))
        request.httpMethod = "GET"

        let payload: [String: Any]
        do {
            payload = try JSONReader.object(try await transport.json(request))
        } catch FundQuoteError.decoding {
            // An unknown ticker answers with something that is not an object.
            return []
        }

        guard let name = try? JSONReader.string(payload["description"]), !name.isEmpty else {
            return []
        }

        // `description` and `type` are taken as a display name only, never as
        // classification: this endpoint returns VESAF as `type: "IFC"` listed on
        // HOSE, and VESAF is an unlisted open-ended fund. The owner confirms the
        // kind before anything is saved.
        return [FundInstrumentCandidate(symbol: wanted, name: name, kind: .etf)]
    }

    /// Every currently listed HOSE ETF that VNDIRECT's symbol search offers.
    ///
    /// The endpoint refuses an empty query, so the catalogue combines the two
    /// ticker families HOSE uses: modern `FUE…` symbols and the original
    /// `E1VFVN30`. Classification is accepted here because this is a provider
    /// catalogue boundary; the exact-symbol search above still treats the
    /// owner's selected kind as authoritative.
    func catalogue() async throws -> [FundInstrumentCandidate] {
        async let fue = catalogue(matching: "FUE")
        async let e1 = catalogue(matching: "E1")

        let combined = try await fue + e1
        var candidatesBySymbol: [String: FundInstrumentCandidate] = [:]
        for candidate in combined {
            candidatesBySymbol[candidate.symbol] = candidate
        }
        return candidatesBySymbol.values.sorted { $0.symbol < $1.symbol }
    }

    private func catalogue(matching query: String) async throws
        -> [FundInstrumentCandidate]
    {
        let rows = try JSONReader.array(
            try await transport.json(catalogueSearchRequest(query: query))
        )

        return try rows.compactMap { value in
            let row = try JSONReader.object(value)
            let exchange = try JSONReader.string(row["exchange"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let type = try JSONReader.string(row["type"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            guard exchange == "HOSE", type == "QUỸ HOÁN ĐỔI DM" else {
                return nil
            }

            let symbol = try JSONReader.string(row["symbol"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            let name = try JSONReader.string(row["description"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !symbol.isEmpty, !name.isEmpty else {
                throw FundQuoteError.decoding
            }

            return FundInstrumentCandidate(symbol: symbol, name: name, kind: .etf)
        }
    }

    private func catalogueSearchRequest(query: String) -> URLRequest {
        let url = Self.searchURL.appending(queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "type", value: ""),
            URLQueryItem(name: "exchange", value: "HOSE"),
            URLQueryItem(name: "limit", value: "100"),
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }

    private func historyRequest(symbol: String, asOf: Date) -> URLRequest {
        let calendar = TradingCalendar.calendar
        let to = calendar.startOfDay(for: asOf).addingTimeInterval(24 * 60 * 60)
        let from =
            calendar.date(byAdding: .day, value: -Self.lookbackDays, to: to)
            ?? to.addingTimeInterval(-TimeInterval(Self.lookbackDays) * 24 * 60 * 60)

        let url = Self.historyURL.appending(queryItems: [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "resolution", value: "D"),
            URLQueryItem(name: "from", value: String(Int(from.timeIntervalSince1970))),
            URLQueryItem(name: "to", value: String(Int(to.timeIntervalSince1970))),
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
}
