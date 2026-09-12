import Foundation
import Network
import Security

struct SyncPairing: Codable, Equatable, Sendable {
    var version = 1
    var flavour = MonMonBackupFlavour.current
    var pairID: UUID
    var hostID: UUID
    var secret: Data

    static func make(hostID: UUID) throws -> SyncPairing {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw SyncError.invalidPairing
        }
        return SyncPairing(pairID: UUID(), hostID: hostID, secret: Data(bytes))
    }

    func code() throws -> String {
        "monmon-pair:" + (try SyncCoding.encode(self)).base64EncodedString()
    }
    static func decode(_ code: String) throws -> SyncPairing {
        guard code.count < 2048, code.hasPrefix("monmon-pair:"),
            let data = Data(base64Encoded: String(code.dropFirst("monmon-pair:".count))),
            let pair = try? JSONDecoder().decode(SyncPairing.self, from: data),
            pair.version == 1, pair.flavour == .current, pair.secret.count == 32
        else { throw SyncError.invalidPairing }
        return pair
    }
}

enum SyncKeychain {
    private static var service: String { "monmon.p2p." + MonMonBackupFlavour.current.rawValue }
    static func save(_ pair: SyncPairing) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: pair.pairID.uuidString,
            kSecAttrSynchronizable as String: false, kSecUseDataProtectionKeychain as String: true,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: try SyncCoding.encode(pair),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            guard
                SecItemAdd(query.merging(attributes) { _, b in b } as CFDictionary, nil)
                    == errSecSuccess
            else { throw SyncError.invalidPairing }
        } else if update != errSecSuccess {
            throw SyncError.invalidPairing
        }
    }
    static func load(_ pairID: UUID) throws -> SyncPairing {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: pairID.uuidString,
            kSecAttrSynchronizable as String: false, kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else { throw SyncError.notPaired }
        let pair = try JSONDecoder().decode(SyncPairing.self, from: data)
        guard pair.pairID == pairID, pair.secret.count == 32, pair.flavour == .current else {
            throw SyncError.invalidPairing
        }
        return pair
    }
    static func delete(_ pairID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: pairID.uuidString,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Length-prefixed messages are capped before allocation. The authenticated
/// protocol carries one snapshot at a time, never an unbounded stream of records.
enum SyncFrame {
    static let maximumSize = MonMonBackupValidator.maximumByteCount + 16 * 1024
    static func header(length: Int) throws -> Data {
        guard length > 0, length <= maximumSize else { throw SyncError.tooLarge }
        var value = UInt32(length).bigEndian
        return withUnsafeBytes(of: &value) { Data($0) }
    }
    static func length(_ header: Data) throws -> Int {
        guard header.count == 4 else { throw SyncError.invalidData }
        let value = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard value > 0, value <= maximumSize else { throw SyncError.tooLarge }
        return Int(value)
    }
}

@MainActor
protocol PeerSyncTransport: AnyObject {
    var onConnected: (() -> Void)? { get set }
    var onMessage: ((Data) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func start(pairing: SyncPairing, isHost: Bool) throws
    func send(_ data: Data) throws
    func stop()
}

/// All callbacks and mutable connection state live on the main queue; socket
/// I/O is handled by Network.framework. No TLS trust bypass is installed.
@MainActor
final class BonjourSyncTransport: PeerSyncTransport {
    var onConnected: (() -> Void)?
    var onMessage: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var timeout: Task<Void, Never>?
    private var ready = false
    private var generation = UUID()

    static var serviceType: String {
        MonMonBackupFlavour.current == .dev ? "_monmon-dev._tcp" : "_monmon._tcp"
    }

    static func parameters(_ pair: SyncPairing) throws -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let identity = Data(pair.pairID.uuidString.utf8)
        let keyData = pair.secret.withUnsafeBytes { DispatchData(bytes: $0) }
        let identityData = identity.withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(
            tls.securityProtocolOptions, keyData as __DispatchData, identityData as __DispatchData)
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        // Apple TN3213: Network.framework TLS-PSK is supported with TLS 1.2 only.
        guard let cipher = tls_ciphersuite_t(rawValue: UInt16(TLS_PSK_WITH_AES_128_GCM_SHA256))
        else { throw SyncError.invalidPairing }
        sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions, cipher)
        sec_protocol_options_set_tls_tickets_enabled(tls.securityProtocolOptions, false)
        sec_protocol_options_add_tls_application_protocol(
            tls.securityProtocolOptions, "monmon-sync/1")
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 15
        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = false
        return parameters
    }

    func start(pairing: SyncPairing, isHost: Bool) throws {
        stop()
        let token = generation
        let parameters = try Self.parameters(pairing)
        if isHost {
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.service = NWListener.Service(
                name: pairing.pairID.uuidString, type: Self.serviceType)
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated {
                    guard let self, self.generation == token, self.connection == nil else {
                        connection.cancel()
                        return
                    }
                    self.attach(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated {
                    if case .failed(let error) = state, self?.generation == token {
                        self?.fail(error)
                    }
                }
            }
            listener.start(queue: .main)
        } else {
            let browser = NWBrowser(
                for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)
            self.browser = browser
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                MainActor.assumeIsolated {
                    guard let self, self.generation == token, self.connection == nil else { return }
                    for result in results {
                        if case .service(let name, _, _, _) = result.endpoint,
                            name == pairing.pairID.uuidString
                        {
                            self.attach(
                                NWConnection(to: result.endpoint, using: parameters))
                            break
                        }
                    }
                }
            }
            browser.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated {
                    if case .failed(let error) = state, self?.generation == token {
                        self?.fail(error)
                    }
                    if case .waiting(let error) = state, self?.generation == token {
                        self?.onError?(error)
                    }
                }
            }
            browser.start(queue: .main)
        }
    }

    /// Internal for loopback transport tests; production connections only come
    /// from the paired Bonjour service above.
    func attach(_ connection: NWConnection) {
        guard self.connection == nil else {
            connection.cancel()
            return
        }
        self.connection = connection
        let token = generation
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, self?.ready == false, self?.generation == token else { return }
            self?.fail(SyncError.disconnected)
        }
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                switch state {
                case .ready:
                    self.ready = true
                    self.timeout?.cancel()
                    self.onConnected?()
                    self.receiveHeader(connection, token: token)
                case .failed(let error): self.fail(error)
                case .cancelled: break
                default: break
                }
            }
        }
        connection.start(queue: .main)
    }

    func send(_ data: Data) throws {
        guard let connection, ready else { throw SyncError.disconnected }
        let framed = try SyncFrame.header(length: data.count) + data
        let token = generation
        connection.send(
            content: framed,
            completion: .contentProcessed { [weak self] error in
                MainActor.assumeIsolated {
                    if let error, self?.generation == token { self?.fail(error) }
                }
            })
    }

    private func receiveHeader(_ connection: NWConnection, token: UUID) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) {
            [weak self] data, _, complete, error in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                do {
                    if let error { throw error }
                    guard let data, !complete else { throw SyncError.disconnected }
                    let length = try SyncFrame.length(data)
                    self.receiveBody(connection, length: length, token: token)
                } catch { self.fail(error) }
            }
        }
    }

    private func receiveBody(_ connection: NWConnection, length: Int, token: UUID) {
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, self?.generation == token else { return }
            self?.fail(SyncError.disconnected)
        }
        connection.receive(minimumIncompleteLength: length, maximumLength: length) {
            [weak self] data, _, complete, error in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.timeout?.cancel()
                guard error == nil, let data, data.count == length, !complete else {
                    self.fail(error ?? SyncError.disconnected)
                    return
                }
                self.onMessage?(data)
                if self.generation == token { self.receiveHeader(connection, token: token) }
            }
        }
    }

    func stop() {
        generation = UUID()
        timeout?.cancel()
        connection?.cancel()
        listener?.cancel()
        browser?.cancel()
        connection = nil
        listener = nil
        browser = nil
        ready = false
    }
    private func fail(_ error: Error) {
        stop()
        onError?(error)
    }
}
