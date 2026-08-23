import Foundation

/// Daily NAV for open-ended fund certificates, from Fmarket's public API.
///
/// The endpoints are undocumented and unauthenticated. They carry no service
/// level, no compatibility promise, and no licence to reuse the data, which is
/// why hand entry stays and why a failure never overwrites a known-good price.
/// Verified working on 2026-08-21.
struct FmarketQuoteProvider: FundQuoteProvider {
    static let filterURL = URL.constant("https://api.fmarket.vn/res/products/filter")
    static let navHistoryURL = URL.constant("https://api.fmarket.vn/res/product/get-nav-history")
    static let pageSize = 100

    let source = FundQuoteSource.fmarket

    private let transport: any FundQuoteTransport

    init(transport: any FundQuoteTransport = URLSessionQuoteTransport()) {
        self.transport = transport
    }

    func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote {
        let wanted = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let productID = try await productID(for: wanted)
        let history = try await transport.json(navHistoryRequest(productID: productID, asOf: asOf))
        let points = try JSONReader.array(JSONReader.object(history)["data"])

        // The reply is the fund's whole history — 1492 points for VESAF — so the
        // last entry is taken and the rest discarded. This module stores no
        // series.
        guard let latest = points.last else {
            throw FundQuoteError.noQuoteAvailable
        }

        let point = try JSONReader.object(latest)
        let price = try JSONReader.price(point["nav"])
        let day = try tradingDay(from: JSONReader.string(point["navDate"]))

        return FundQuote(symbol: wanted, pricePerUnit: price, asOf: day, source: source)
    }

    func search(_ query: String) async throws -> [FundInstrumentCandidate] {
        try await candidates(searchField: query)
    }

    /// Every open-ended fund Fmarket lists, with the NAV each one already
    /// carries.
    ///
    /// One request for the whole catalogue — 68 funds on 2026-08-21 — so the
    /// owner can import the list instead of typing a ticker, a name and a price
    /// per fund. Nothing is written until they choose.
    func catalogue() async throws -> [FundInstrumentCandidate] {
        try await candidates(searchField: "")
    }

    private func candidates(searchField: String) async throws -> [FundInstrumentCandidate] {
        let rows = try await rows(searchField: searchField)

        return try rows.map { row in
            let object = try JSONReader.object(row)
            let change = (object["productNavChange"] as? [String: Any]) ?? [:]

            return FundInstrumentCandidate(
                symbol: try JSONReader.string(object["shortName"]).uppercased(),
                name: try JSONReader.string(object["name"]),
                // Everything this endpoint lists is an open-ended fund.
                kind: .fund,
                pricePerUnit: try? JSONReader.price(object["nav"]),
                priceAsOf: Self.tradingDay(fromMilliseconds: change["updateAt"]),
                owner: (object["owner"] as? [String: Any])
                    .flatMap { $0["name"] as? String } ?? ""
            )
        }
    }

    /// `updateAt` is epoch milliseconds. A listing with no usable stamp yields
    /// no date rather than a guess, and the import falls back to asking.
    private static func tradingDay(fromMilliseconds value: Any?) -> Date? {
        guard let number = value as? NSNumber else {
            return nil
        }
        let seconds = number.doubleValue / 1_000
        guard seconds > 0 else {
            return nil
        }
        return TradingCalendar.calendar.startOfDay(for: Date(timeIntervalSince1970: seconds))
    }

    // MARK: - Fmarket keys funds by an internal id, not by ticker

    private func productID(for symbol: String) async throws -> Int {
        let rows = try await rows(searchField: symbol)

        for row in rows {
            let object = try JSONReader.object(row)
            let shortName = try JSONReader.string(object["shortName"]).uppercased()
            if shortName == symbol {
                return try JSONReader.int(object["id"])
            }
        }

        throw FundQuoteError.symbolNotFound
    }

    private func rows(searchField: String) async throws -> [Any] {
        let payload: [String: Any] = [
            "searchField": searchField.trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
            "types": ["NEW_FUND", "TRADING_FUND"],
            "pageSize": Self.pageSize,
        ]

        let value = try await transport.json(Self.request(url: Self.filterURL, payload: payload))
        let data = try JSONReader.object(JSONReader.object(value)["data"])
        return try JSONReader.array(data["rows"])
    }

    private func navHistoryRequest(productID: Int, asOf: Date) -> URLRequest {
        // `isAllData` must be 1. Sending 0 returns HTTP 400.
        let payload: [String: Any] = [
            "isAllData": 1,
            "productId": productID,
            "fromDate": NSNull(),
            "toDate": Self.compactDay.string(from: asOf),
        ]
        return Self.request(url: Self.navHistoryURL, payload: payload)
    }

    private func tradingDay(from text: String) throws -> Date {
        guard let day = Self.navDay.date(from: text) else {
            throw FundQuoteError.decoding
        }
        return TradingCalendar.calendar.startOfDay(for: day)
    }

    private static func request(url: URL, payload: [String: Any]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return request
    }

    /// Both formatters are fixed to the shared calendar and a stable locale, so
    /// nothing here depends on the machine's region.
    private static let navDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = TradingCalendar.calendar
        formatter.timeZone = TradingCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let compactDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = TradingCalendar.calendar
        formatter.timeZone = TradingCalendar.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
