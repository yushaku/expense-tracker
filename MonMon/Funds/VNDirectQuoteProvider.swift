import Foundation

/// Closing price for ETFs listed on HOSE, from VNDIRECT's chart API.
///
/// A TradingView UDF endpoint: plain GET, no authentication, no service level
/// and no licence to reuse the data. Verified working on 2026-08-21.
struct VNDirectQuoteProvider: FundQuoteProvider {
    static let historyURL = URL.constant("https://dchart-api.vndirect.com.vn/dchart/history")
    static let symbolsURL = URL.constant("https://dchart-api.vndirect.com.vn/dchart/symbols")

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

    func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote {
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
