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
    /// `GET /api/prices?type=SJL1L10`, captured 2026-08-24.
    static let vangTodaySJC9999 = """
        {"success":true,"timestamp":1787544005,"time":"11:00","date":"2026-08-24",
         "type":"SJL1L10","name":"SJC 9999","buy":147000000,"sell":150000000,
         "change_buy":1000000,"change_sell":1000000}
        """

    /// `GET /api/prices`, trimmed to two VND rows and the USD/oz row that must
    /// never enter this VND-only catalogue.
    static let vangTodayCatalogue = """
        {"success":true,"timestamp":1787544005,"time":"11:00","date":"2026-08-24",
         "count":3,"prices":{
           "SJL1L10":{"name":"SJC 9999","buy":147000000,"sell":150000000,
                      "change_buy":1000000,"change_sell":1000000,"currency":"VND"},
           "DOHCML":{"name":"DOJI HCM","buy":146500000,"sell":149500000,
                     "change_buy":500000,"change_sell":500000,"currency":"VND"},
           "XAUUSD":{"name":"World Gold","buy":3370.4,"sell":3371.1,
                     "change_buy":1.2,"change_sell":1.3,"currency":"USD"}
         }}
        """

    static let vangTodayUnknownType = """
        {"success":true,"timestamp":1787544005,"date":"2026-08-24","type":"OTHER",
         "name":"Other","buy":147000000,"sell":150000000}
        """

    static let vangTodayFailure = """
        {"success":false,"message":"Type not found"}
        """

    static let vangTodayRenamedBuy = """
        {"success":true,"timestamp":1787544005,"date":"2026-08-24","type":"SJL1L10",
         "name":"SJC 9999","purchase":147000000,"sell":150000000}
        """

    static let vangTodayZeroBuy = """
        {"success":true,"timestamp":1787544005,"date":"2026-08-24","type":"SJL1L10",
         "name":"SJC 9999","buy":0,"sell":150000000}
        """

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
        {"status":200,"data":{"total":4,"rows":[
          {"id":70,"shortName":"UMMF","name":"QUY DAU TU TIEN TE UOB",
           "nav":10000.0,"productNavChange":{"updateAt":1787420400000},
           "owner":{"id":1,"name":"CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ UOB ASSET MANAGEMENT (VIỆT NAM)",
                     "avatarUrl":"http://files.fmarket.vn/pro/user/1/uob.png"}},
          {"id":23,"shortName":"vesaf","name":"QUỸ ĐẦU TƯ CỔ PHIẾU TIẾP CẬN THỊ TRƯỜNG VINACAPITAL",
           "nav":31581.76,"productNavChange":{"updateAt":1787420400000},
           "owner":{"id":2,"name":"CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ VINACAPITAL",
                    "avatarUrl":"https://files.fmarket.vn/pro/user/2/vcam.png?timestamp=1"}},
          {"id":24,"shortName":"VEOF","name":"QUỸ ĐẦU TƯ CỔ PHIẾU HƯNG THỊNH VINACAPITAL",
           "nav":28000.5,"productNavChange":{"updateAt":1787420400000},
           "owner":{"id":2,"name":"CÔNG TY CỔ PHẦN QUẢN LÝ QUỸ VINACAPITAL",
                    "avatarUrl":"https://files.fmarket.vn/pro/user/2/vcam.png?timestamp=1"}},
          {"id":91,"shortName":"AEIF","name":"QUỸ ĐẦU TƯ CỔ PHIẾU AMBER","nav":9348.31}
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

    /// `GET /dchart/search?query=FUE...`, trimmed to two listed ETFs and rows
    /// that look similar but must not enter the catalogue.
    static let vndirectSearchFUE = """
        [
          {"symbol":"FUEVFVND","full_name":"FUEVFVND",
           "description":"Quỹ ETF DCVFMVN DIAMOND","exchange":"HOSE",
           "type":"QUỸ HOÁN ĐỔI DM"},
          {"symbol":"FUESSVFL","full_name":"FUESSVFL",
           "description":"SSIAM VNFIN LEAD","exchange":"HOSE",
           "type":"QUỸ HOÁN ĐỔI DM"},
          {"symbol":"FUCVREIT","full_name":"FUCVREIT",
           "description":"Quỹ BĐS Techcom VN","exchange":"HOSE",
           "type":"CHỨNG CHỈ QUỸ"},
          {"symbol":"FUEHNX30","full_name":"FUEHNX30",
           "description":"ETF on another exchange","exchange":"HNX",
           "type":"QUỸ HOÁN ĐỔI DM"}
        ]
        """

    /// The `E1` family currently contains HOSE's original ETF ticker. A
    /// duplicate proves the combined catalogue is stable when families overlap.
    static let vndirectSearchE1 = """
        [
          {"symbol":"E1VFVN30","full_name":"E1VFVN30",
           "description":"Quỹ ETF DCVFMVN30","exchange":"HOSE",
           "type":"QUỸ HOÁN ĐỔI DM"},
          {"symbol":"FUEVFVND","full_name":"FUEVFVND",
           "description":"Quỹ ETF DCVFMVN DIAMOND","exchange":"HOSE",
           "type":"QUỸ HOÁN ĐỔI DM"},
          {"symbol":"E12","full_name":"E12",
           "description":"Xây dựng điện VNECO12","exchange":"UPCOM",
           "type":"CỔ PHIẾU"}
        ]
        """

    /// `GET /api/v3/simple/price?ids=bitcoin&vs_currencies=vnd&include_last_updated_at=true`,
    /// captured 2026-09-04.
    static let coinGeckoPriceBitcoin = """
        {"bitcoin":{"vnd":2110324943,"last_updated_at":1788514270}}
        """

    /// What an identifier CoinGecko does not know is answered with. Not an
    /// error, and not a malformed body — an empty object.
    static let coinGeckoPriceUnknown = """
        {}
        """

    /// A coin CoinGecko knows, quoted in a currency that was not asked for.
    static let coinGeckoPriceWrongCurrency = """
        {"bitcoin":{"usd":80123.45,"last_updated_at":1788514270}}
        """

    /// `GET /api/v3/coins/markets?vs_currency=vnd`, trimmed to the fields the
    /// provider reads, plus one row with no usable price.
    static let coinGeckoMarkets = """
        [{"id":"bitcoin","symbol":"btc","name":"Bitcoin",
          "image":"https://coin-images.coingecko.com/coins/images/1/large/bitcoin.png",
          "current_price":2110321939,"market_cap_rank":1,
          "last_updated":"2026-09-04T09:30:30.000Z"},
         {"id":"ethereum","symbol":"eth","name":"Ethereum",
          "image":"https://coin-images.coingecko.com/coins/images/279/large/ethereum.png",
          "current_price":76543210,"market_cap_rank":2,
          "last_updated":"2026-09-04T09:30:31.000Z"},
         {"id":"unpriced-coin","symbol":"nop","name":"Unpriced Coin",
          "image":"https://coin-images.coingecko.com/coins/images/3/large/nope.png",
          "current_price":null,"market_cap_rank":null,
          "last_updated":"2026-09-04T09:30:32.000Z"}]
        """

    /// `GET /api/v3/search?query=pepe`, captured 2026-09-04.
    static let coinGeckoSearchPepe = """
        {"coins":[
          {"id":"pepe","name":"Pepe","api_symbol":"pepe","symbol":"PEPE",
           "market_cap_rank":54,
           "thumb":"https://coin-images.coingecko.com/coins/images/29850/thumb/pepe-token.jpeg",
           "large":"https://coin-images.coingecko.com/coins/images/29850/large/pepe-token.jpeg"},
          {"id":"ape-and-pepe","name":"Ape and Pepe","api_symbol":"ape-and-pepe",
           "symbol":"APEPE","market_cap_rank":163,
           "thumb":"https://coin-images.coingecko.com/coins/images/39614/thumb/APEPE_200.png",
           "large":"https://coin-images.coingecko.com/coins/images/39614/large/APEPE_200.png"}
        ],"exchanges":[],"categories":[]}
        """

    static let coinGeckoSearchEmpty = """
        {"coins":[],"exchanges":[],"categories":[]}
        """

    /// `GET /api/v3/simple/price?ids=tether&vs_currencies=vnd&include_last_updated_at=true`,
    /// captured 2026-09-04. The dollar, priced in đồng.
    static let coinGeckoTetherRate = """
        {"tether":{"vnd":26058,"last_updated_at":1788538300}}
        """

    /// What the free tier answers with once it has had enough.
    static let coinGeckoThrottled = """
        {"status":{"error_code":429,"error_message":"You've exceeded the Rate Limit"}}
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
