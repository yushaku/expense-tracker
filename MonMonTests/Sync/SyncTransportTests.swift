import Foundation
import Network
import Testing

@testable import MonMon

@Suite("P2P framing and authentication")
struct SyncTransportTests {
    @Test("Invalid sizes are rejected before allocating a payload")
    func bounds() throws {
        #expect(throws: SyncError.tooLarge) { try SyncFrame.header(length: 0) }
        #expect(throws: SyncError.tooLarge) { try SyncFrame.length(Data([255, 255, 255, 255])) }
        #expect(try SyncFrame.length(SyncFrame.header(length: 12345)) == 12345)
    }
    @Test("Pairing codes reject malformed and wrong-flavour values")
    func pairing() throws {
        let pair = try SyncPairing.make(hostID: UUID())
        #expect(try SyncPairing.decode(pair.code()) == pair)
        var wrong = pair
        wrong.flavour = pair.flavour == .dev ? .prod : .dev
        #expect(throws: SyncError.invalidPairing) { try SyncPairing.decode(wrong.code()) }
        #expect(throws: SyncError.invalidPairing) { try SyncPairing.decode("http://example.com") }
    }

    @Test("TLS PSK only delivers messages with the paired secret", arguments: [false, true])
    @MainActor
    func loopback(wrongSecret: Bool) async throws {
        let pair = try SyncPairing.make(hostID: UUID())
        let server = BonjourSyncTransport()
        let client = BonjourSyncTransport()
        let parameters = try BonjourSyncTransport.parameters(pair)
        var clientPair = pair
        if wrongSecret { clientPair.secret = Data(repeating: 17, count: 32) }
        let clientParameters = try BonjourSyncTransport.parameters(clientPair)
        let listener = try NWListener(using: parameters, on: .any)
        defer {
            listener.cancel()
            server.stop()
            client.stop()
        }
        var received: Data?
        var failure: Error?
        var details: [String] = []
        server.onMessage = { received = $0 }
        server.onError = {
            details.append("server: " + $0.localizedDescription)
            failure = $0
        }
        client.onError = {
            details.append("client: " + $0.localizedDescription)
            failure = $0
        }
        client.onConnected = {
            do { try client.send(Data("hello".utf8)) } catch { failure = error }
        }
        listener.newConnectionHandler = { connection in
            MainActor.assumeIsolated { server.attach(connection) }
        }
        listener.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                if case .ready = state, let port = listener.port {
                    client.attach(
                        NWConnection(
                            host: "127.0.0.1", port: port,
                            using: clientParameters))
                }
                if case .failed(let error) = state { failure = error }
            }
        }
        listener.start(queue: .main)
        for _ in 0..<100 {
            if received != nil || failure != nil { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        if wrongSecret {
            #expect(failure != nil)
            #expect(received == nil)
        } else {
            #expect(failure == nil, "\(details)")
            #expect(received == Data("hello".utf8))
        }
    }
}
