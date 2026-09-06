import Foundation

/// Physical-gold shop prices from vang.today's public API.
///
/// The endpoint is undocumented and unauthenticated. It carries no service
/// level, no compatibility promise, and no licence to reuse the data, which is
/// why hand entry stays and why a failure never overwrites a known-good price.
/// Verified working on 2026-08-24.
struct VangTodayQuoteProvider: FundCatalogueProvider {
    static let pricesURL = URL.constant("https://www.vang.today/api/prices")

    let source = FundQuoteSource.vangToday

    private let transport: any FundQuoteTransport

    init(transport: any FundQuoteTransport = URLSessionQuoteTransport()) {
        self.transport = transport
    }

    func latestQuote(symbol: String, providerID: String?, asOf: Date) async throws -> FundQuote {
        let wanted = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let url = Self.pricesURL.appending(queryItems: [
            URLQueryItem(name: "type", value: wanted)
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = try JSONReader.object(try await transport.json(request))
        guard try JSONReader.bool(payload["success"]) else {
            throw FundQuoteError.symbolNotFound
        }

        let returned = try JSONReader.string(payload["type"]).uppercased()
        guard returned == wanted else {
            throw FundQuoteError.symbolNotFound
        }

        _ = try JSONReader.string(payload["name"])
        return FundQuote(
            symbol: wanted,
            pricePerUnit: try JSONReader.price(payload["buy"]),
            askPricePerUnit: try JSONReader.price(payload["sell"]),
            asOf: try tradingDay(from: JSONReader.string(payload["date"])),
            source: source
        )
    }

    func catalogue() async throws -> [FundInstrumentCandidate] {
        var request = URLRequest(url: Self.pricesURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = try JSONReader.object(try await transport.json(request))
        guard try JSONReader.bool(payload["success"]) else {
            throw FundQuoteError.symbolNotFound
        }

        let day = try tradingDay(from: JSONReader.string(payload["date"]))
        let prices = try JSONReader.object(payload["prices"])

        return try prices.compactMap { symbol, value in
            let row = try JSONReader.object(value)
            guard try JSONReader.string(row["currency"]).uppercased() == VNDCurrency.code else {
                return nil
            }

            let code = symbol.uppercased()
            return FundInstrumentCandidate(
                symbol: code,
                name: try JSONReader.string(row["name"]),
                kind: .gold,
                pricePerUnit: try JSONReader.price(row["buy"]),
                askPricePerUnit: try JSONReader.price(row["sell"]),
                priceAsOf: day,
                owner: Self.brand(for: code)
            )
        }
        .sorted { $0.symbol < $1.symbol }
    }

    func search(_ query: String) async throws -> [FundInstrumentCandidate] {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = try await catalogue()
        guard !wanted.isEmpty else {
            return candidates
        }

        return candidates.filter { candidate in
            candidate.symbol.localizedCaseInsensitiveContains(wanted)
                || candidate.name.localizedCaseInsensitiveContains(wanted)
                || candidate.owner.localizedCaseInsensitiveContains(wanted)
        }
    }

    private func tradingDay(from text: String) throws -> Date {
        guard let day = Self.priceDay.date(from: text) else {
            throw FundQuoteError.decoding
        }
        return TradingCalendar.calendar.startOfDay(for: day)
    }

    private static func brand(for symbol: String) -> String {
        switch symbol {
        case "SJ9999", "SJL1L10":
            "SJC"
        case "BTSJC", "BT9999NTT":
            "Bảo Tín"
        case "VNGSJC":
            "VN Gold"
        case "DOJINHTV", "DOHNL", "DOHCML":
            "DOJI"
        case "VIETTINMSJC":
            "Viettin"
        case "PQHNVM", "PQHN24NTT":
            "PNJ"
        default:
            "Other"
        }
    }

    private static let priceDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = TradingCalendar.calendar
        formatter.timeZone = TradingCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
