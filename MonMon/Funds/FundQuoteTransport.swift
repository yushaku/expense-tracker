import Foundation

/// The one place this app talks to the network.
///
/// A protocol rather than a bare `URLSession` call so every provider test runs
/// against a recorded reply. A suite that depends on Fmarket being up is a suite
/// that fails on a plane, and a green run has to mean the code is right.
protocol FundQuoteTransport: Sendable {
    /// - Returns: the body and the status code, or throws `FundQuoteError`.
    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int)
}

/// The live transport.
///
/// Ephemeral, so nothing is cached to disk, no cookie is kept, and no credential
/// store is consulted. Only a ticker ever goes out — never a balance, a unit
/// count, a cost basis, an account name, or anything identifying the owner.
struct URLSessionQuoteTransport: FundQuoteTransport {
    static let timeout: TimeInterval = 10

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw FundQuoteError.transport
            }
            return (data, http.statusCode)
        } catch let error as FundQuoteError {
            throw error
        } catch {
            throw FundQuoteError.transport
        }
    }
}

extension FundQuoteTransport {
    /// Sends a request and hands back parsed JSON, mapping every failure onto a
    /// typed error. One retry on `transport` and none on anything else: a
    /// timeout is worth a second try, a changed response shape is not.
    func json(_ request: URLRequest, retries: Int = 1) async throws -> Any {
        do {
            let (data, statusCode) = try await send(request)

            guard (200..<300).contains(statusCode) else {
                throw FundQuoteError.transport
            }

            do {
                return try JSONSerialization.jsonObject(with: data)
            } catch {
                throw FundQuoteError.decoding
            }
        } catch FundQuoteError.transport where retries > 0 {
            return try await json(request, retries: retries - 1)
        }
    }
}

extension URL {
    /// A URL built from a string constant compiled into the app.
    ///
    /// Not a force unwrap: the argument is a `StaticString`, so the only way
    /// this can fail is a typo in this source file, and trapping with the text
    /// says which one. Endpoint constants would otherwise have to be optional
    /// everywhere for a case that cannot happen at runtime.
    static func constant(_ text: StaticString) -> URL {
        guard let url = URL(string: "\(text)") else {
            preconditionFailure("Malformed constant URL: \(text)")
        }
        return url
    }
}

/// Reads values out of parsed JSON without ever routing a price through a
/// binary floating-point type.
///
/// `JSONSerialization` hands back an `NSNumber`. Getting a `Decimal` out of it
/// without picking up the binary artefact takes some care:
///
/// - `NSNumber.decimalValue` goes through the `Double`, so it inherits the
///   artefact outright.
/// - `NSNumber.stringValue` formats with `%0.16g`, which *prints* the artefact:
///   a NAV of `9348.31` comes back as `"9348.310000000001"`. `34.2` happens not
///   to, which is why this looked fine until a fund whose price exposed it
///   arrived.
/// - Swift's own `Double.description` is the shortest text that round-trips, so
///   `9348.31` prints as `9348.31` and `34.2` as `34.2`.
///
/// The last one is what this uses. Integer-valued numbers are read as integers
/// so a count never picks up a decimal point.
enum JSONReader {
    static func object(_ value: Any?) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw FundQuoteError.decoding
        }
        return object
    }

    static func array(_ value: Any?) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw FundQuoteError.decoding
        }
        return array
    }

    static func string(_ value: Any?) throws -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        throw FundQuoteError.decoding
    }

    /// The shortest text that round-trips back to the same number. See the note
    /// on this type for why neither `stringValue` nor `decimalValue` will do.
    static func exactText(_ number: NSNumber) -> String {
        if CFNumberIsFloatType(number) {
            return String(number.doubleValue)
        }
        return number.stringValue
    }

    static func int(_ value: Any?) throws -> Int {
        guard let number = value as? NSNumber else {
            throw FundQuoteError.decoding
        }
        return number.intValue
    }

    static func bool(_ value: Any?) throws -> Bool {
        guard let number = value as? NSNumber,
            CFGetTypeID(number) == CFBooleanGetTypeID()
        else {
            throw FundQuoteError.decoding
        }
        return number.boolValue
    }

    /// A price, read through its textual form. Must be greater than zero: a zero
    /// or negative figure is a malformed response, not a price.
    static func price(_ value: Any?) throws -> Decimal {
        guard let number = value as? NSNumber,
            let decimal = Decimal(string: exactText(number))
        else {
            throw FundQuoteError.decoding
        }

        guard decimal > 0 else {
            throw FundQuoteError.decoding
        }

        return decimal
    }
}
