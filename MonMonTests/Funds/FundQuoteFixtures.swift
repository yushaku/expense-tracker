import Foundation

@testable import MonMon

/// Recorded replies, captured from the live endpoints on 2026-08-21 and trimmed
/// to the fields the providers read.
///
/// Committed so a decoder change that breaks on real data is caught without a
/// request. No test in the default run touches the network: a suite that depends
/// on Fmarket being up is a suite that fails on a plane, and a green run has to
/// mean the code is right rather than that the internet is.
enum FundQuoteFixtures {
    /// `POST /res/products/filter` with `searchField: "VESAF"`.
    static let fmarketFilterVESAF = """
        {"status":200,"data":{"total":1,"rows":[
          {"id":23,"shortName":"VESAF","name":"QUY DAU TU CO PHIEU TIEP CAN THI TRUONG VINACAPITAL",
           "nav":31581.76}
        ]}}
        """

    /// `POST /res/products/filter` with an empty `searchField` — the whole
    /// catalogue. Trimmed to three of the 68 funds it returned on 2026-08-23,
    /// keeping one that carries no `productNavChange` at all.
    static let fmarketCatalogue = """
        {"status":200,"data":{"total":3,"rows":[
          {"id":70,"shortName":"UMMF","name":"QUY DAU TU TIEN TE UOB",
           "nav":10000.0,"productNavChange":{"updateAt":1787420400000}},
          {"id":23,"shortName":"vesaf","name":"QUY VESAF",
           "nav":31581.76,"productNavChange":{"updateAt":1787420400000}},
          {"id":91,"shortName":"AEIF","name":"QUY AE INNOVATION","nav":9348.31}
        ]}}
        """

    /// The same call for a ticker Fmarket does not list.
    static let fmarketFilterEmpty = """
        {"status":200,"data":{"total":0,"rows":[]}}
        """

    /// `POST /res/product/get-nav-history` with `isAllData: 1`, last three points.
    static let fmarketNavHistoryVESAF = """
        {"status":200,"data":[
          {"id":58020,"nav":31649.58,"navDate":"2026-08-19","productId":23},
          {"id":58076,"nav":31517.77,"navDate":"2026-08-20","productId":23},
          {"id":58134,"nav":31581.76,"navDate":"2026-08-21","productId":23}
        ]}
        """

    static let fmarketNavHistoryEmpty = """
        {"status":200,"data":[]}
        """

    /// A field this build does not know how to read.
    static let fmarketNavHistoryRenamed = """
        {"status":200,"data":[{"id":58134,"netAssetValue":31581.76,"navDate":"2026-08-21"}]}
        """

    /// `GET /dchart/history?symbol=FUEVFVND&resolution=D`, last three bars.
    /// Closes are in thousands of đồng.
    static let vndirectHistoryFUEVFVND = """
        {"t":[1787097600,1787184000,1787270400],
         "c":[33.37,33.5,34.2],
         "o":[33.2,33.4,33.6],"h":[33.6,33.7,34.3],"l":[33.1,33.3,33.5],
         "v":[100,200,300],"s":"ok"}
        """

    static let vndirectHistoryNoData = """
        {"s":"no_data"}
        """

    static let vndirectHistoryEmpty = """
        {"t":[],"c":[],"s":"ok"}
        """

    /// A close of zero is a malformed reply, not a price.
    static let vndirectHistoryZeroClose = """
        {"t":[1787270400],"c":[0],"s":"ok"}
        """

    /// `GET /dchart/symbols?symbol=FUEVFVND`.
    static let vndirectSymbolsFUEVFVND = """
        {"name":"FUEVFVND","symbol":"FUEVFVND","exchange-traded":"HOSE","exchange-listed":"HOSE",
         "timezone":"Asia/Bangkok","session":"0900-1500","has_intraday":true,
         "description":"Quỹ ETF DCVFMVN DIAMOND","type":"ETF"}
        """

    /// The same call for VESAF. Every classification field here is wrong — VESAF
    /// is an unlisted open-ended fund, not a HOSE-listed VN100 ETF — which is why
    /// nothing but the owner's own choice decides an instrument's kind.
    static let vndirectSymbolsVESAF = """
        {"name":"VESAF","symbol":"VESAF","exchange-traded":"HOSE","exchange-listed":"HOSE",
         "session":"0900-1500","description":"VINACAPITAL VN100 ETF","type":"IFC"}
        """
}

/// Serves recorded replies, and records what was asked for so a test can assert
/// that only a ticker ever leaves.
final class FixtureTransport: FundQuoteTransport, @unchecked Sendable {
    struct Reply {
        var body: String
        var statusCode: Int

        init(_ body: String, statusCode: Int = 200) {
            self.body = body
            self.statusCode = statusCode
        }
    }

    /// Matched against the request URL, longest pattern first.
    private let replies: [(pattern: String, reply: Reply)]
    private let lock = NSLock()
    private var _requests: [URLRequest] = []

    /// Every request the provider made, in order.
    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    var requestCount: Int {
        requests.count
    }

    /// Kept out of the async method: `NSLock` may not be taken across a
    /// suspension point, and this never suspends.
    private func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        _requests.append(request)
    }

    init(_ replies: [String: Reply]) {
        self.replies = replies.sorted { $0.key.count > $1.key.count }
            .map { (pattern: $0.key, reply: $0.value) }
    }

    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        record(request)

        let url = request.url?.absoluteString ?? ""
        guard let match = replies.first(where: { url.contains($0.pattern) }) else {
            throw FundQuoteError.transport
        }

        return (Data(match.reply.body.utf8), match.reply.statusCode)
    }

    /// Everything the transport was asked to send: URLs and bodies together.
    /// Used to prove no position data crosses the boundary.
    func allSentText() -> String {
        requests.map { request in
            let url = request.url?.absoluteString ?? ""
            let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            return url + " " + body
        }
        .joined(separator: "\n")
    }
}

/// Fails every request, for the offline path.
struct FailingTransport: FundQuoteTransport {
    var error: FundQuoteError = .transport

    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        throw error
    }
}
