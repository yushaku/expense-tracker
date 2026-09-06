import Foundation
import Observation
import SwiftData

#if os(iOS)
    import UIKit
#endif

struct SyncHello: Codable, Sendable {
    var version = 1
    var flavour = MonMonBackupFlavour.current
    var pairID: UUID
    var deviceID: UUID
    var name: String
    var baselineDigest: String?
    var pendingID: UUID?
    var pendingApplied: Bool
    var pendingDigest: String?
    var completedID: UUID?
}

struct SyncMessage: Codable, Sendable {
    enum Kind: String, Codable {
        case hello, request, snapshot, prepare, prepared, commit, committed, complete, finished,
            cancel, failure
    }
    var kind: Kind
    var id: UUID?
    var hello: SyncHello?
    var snapshot: SyncSnapshot?
    var expectedDigest: String?
    var otherDigest: String?
    var choices: [String: Int]?
}

@MainActor
@Observable
final class SyncCoordinator {
    enum Phase: String {
        case idle = "Ready to connect"
        case waiting = "Waiting for the other device"
        case connected = "Connected"
        case comparing = "Comparing data"
        case review = "Review changes"
        case receiving = "The other device is reviewing changes"
        case applying = "Applying changes"
        case complete = "Sync complete"
        case interrupted = "Sync incomplete"
    }

    var isPresented = false
    private(set) var phase: Phase = .idle
    private(set) var errorMessage: String?
    private(set) var peerName = ""
    private(set) var pairingCode: String?
    private(set) var isPaired = false
    private(set) var reports: [SyncReport] = []
    private(set) var plan: SyncMergePlan?
    var choices: [String: Int] = [:]
    private(set) var contentRevision = 0
    private(set) var writesLocked = false
    private(set) var hasPending = false
    private(set) var previewLocal: [SyncChange] = []
    private(set) var previewRemote: [SyncChange] = []
    @ObservationIgnored let store: SyncSessionStore
    @ObservationIgnored private let transport: any PeerSyncTransport
    @ObservationIgnored private let loadPairing: (UUID) throws -> SyncPairing
    @ObservationIgnored private let savePairing: (SyncPairing) throws -> Void
    @ObservationIgnored private let deletePairing: (UUID) -> Void
    @ObservationIgnored private var pair: SyncPairing?
    @ObservationIgnored private var peer: SyncHello?
    @ObservationIgnored private var requestID: UUID?
    @ObservationIgnored private var initiator = false
    @ObservationIgnored private var localSnapshot: SyncSnapshot?
    @ObservationIgnored private var remoteSnapshot: SyncSnapshot?
    @ObservationIgnored private var proposedSession: SyncSession?
    @ObservationIgnored private var stageTimeout: Task<Void, Never>?
    @ObservationIgnored var onApplied: (() -> Void)?
    @ObservationIgnored var mayConnect: () -> Bool = { true }

    init(
        store: SyncSessionStore, transport: (any PeerSyncTransport)? = nil,
        loadPairing: @escaping (UUID) throws -> SyncPairing = SyncKeychain.load,
        savePairing: @escaping (SyncPairing) throws -> Void = SyncKeychain.save,
        deletePairing: @escaping (UUID) -> Void = SyncKeychain.delete
    ) {
        self.store = store
        self.loadPairing = loadPairing
        self.savePairing = savePairing
        self.deletePairing = deletePairing
        self.transport = transport ?? BonjourSyncTransport()
        self.transport.onConnected = { [weak self] in self?.connected() }
        self.transport.onMessage = { [weak self] in self?.receive($0) }
        self.transport.onError = { [weak self] error in self?.fail(error) }
        refresh()
    }

    var canStart: Bool { (phase == .connected || phase == .complete) && peer != nil && !hasPending }
    var canApply: Bool {
        phase == .review && (try? plan?.resolved(choices)) != nil
    }

    func refresh() {
        do {
            let state = try store.state()
            isPaired = state.pairID != nil
            peerName = state.peerName
            reports = state.reports
            hasPending = state.pending != nil
            setLocked(state.pending != nil && state.pending?.applied == false)
        } catch {
            setLocked(true)
            errorMessage = error.localizedDescription
        }
    }

    func createPairing() {
        perform {
            guard try store.state().pending == nil, !isPaired else {
                throw SyncError.sessionPending
            }
            let pairing = try SyncPairing.make(hostID: store.state().deviceID)
            try installPairing(pairing)
            pairingCode = try pairing.code()
            connect()
        }
    }

    func acceptPairing(_ code: String) {
        perform {
            guard try store.state().pending == nil, !isPaired else {
                throw SyncError.sessionPending
            }
            let pairing = try SyncPairing.decode(code)
            guard pairing.hostID != (try store.state().deviceID) else {
                throw SyncError.invalidPairing
            }
            try installPairing(pairing)
            connect()
        }
    }

    private func installPairing(_ pairing: SyncPairing) throws {
        try savePairing(pairing)
        try store.updateState {
            $0.pairID = pairing.pairID
            $0.peerID = nil
            $0.commonBaselineValid = false
        }
        pair = pairing
        refresh()
    }

    func connect() {
        perform {
            guard mayConnect() else { throw SyncError.disconnected }
            let state = try store.state()
            guard let pairID = state.pairID else { throw SyncError.notPaired }
            let pairing = try pair ?? loadPairing(pairID)
            pair = pairing
            if state.deviceID == pairing.hostID && state.peerID == nil {
                pairingCode = try pairing.code()
            }
            peer = nil
            requestID = nil
            plan = nil
            proposedSession = nil
            errorMessage = nil
            phase = .waiting
            try transport.start(pairing: pairing, isHost: state.deviceID == pairing.hostID)
        }
    }

    func disconnect() {
        transport.stop()
        stageTimeout?.cancel()
        peer = nil
        pairingCode = nil
        plan = nil
        requestID = nil
        refresh()
        phase = hasPending ? .interrupted : .idle
    }

    func unpair() {
        perform {
            let state = try store.state()
            try store.unpair()
            if let id = state.pairID { deletePairing(id) }
            pair = nil
            disconnect()
        }
    }

    func startSync() {
        perform {
            guard canStart else { throw SyncError.sessionPending }
            try SyncWriteGate.save(store.container.mainContext)
            localSnapshot = try store.snapshot()
            remoteSnapshot = nil
            plan = nil
            choices = [:]
            errorMessage = nil
            initiator = true
            requestID = UUID()
            phase = .comparing
            try send(SyncMessage(kind: .request, id: requestID, snapshot: localSnapshot))
            armTimeout()
        }
    }

    func updatePreview() {
        guard let plan, let localSnapshot, let remoteSnapshot else { return }
        do {
            previewLocal = try plan.changes(from: localSnapshot, choices: choices)
            previewRemote = try plan.changes(from: remoteSnapshot, choices: choices)
            errorMessage = nil
        } catch {
            previewLocal = []
            previewRemote = []
            if error as? SyncError != .unresolvedConflicts {
                errorMessage = error.localizedDescription
            }
        }
    }

    func apply() {
        perform {
            guard canApply, let plan, let id = requestID, let localSnapshot, let remoteSnapshot
            else { throw SyncError.unresolvedConflicts }
            if let proposedSession {
                setLocked(true)
                try store.prepare(proposedSession)
                self.proposedSession = nil
                phase = .applying
                refresh()
                try send(SyncMessage(kind: .prepared, id: id))
                armTimeout()
                return
            }
            let target = try plan.finalized(choices)
            let ownDigest = try localSnapshot.digest()
            let otherDigest = try remoteSnapshot.digest()
            setLocked(true)
            try store.prepare(
                SyncSession(
                    id: id, target: target, expectedLocalDigest: ownDigest, applied: false,
                    expectedRemoteDigest: otherDigest))
            phase = .applying
            refresh()
            try send(
                SyncMessage(
                    kind: .prepare, id: id, snapshot: target, expectedDigest: otherDigest,
                    otherDigest: ownDigest, choices: choices))
            stageTimeout?.cancel()  // The other device must approve its preview.
        }
    }

    func cancelReview() {
        perform {
            guard try store.state().pending == nil else { throw SyncError.sessionPending }
            if let id = requestID { try send(SyncMessage(kind: .cancel, id: id)) }
            resetReview()
        }
    }

    private func connected() {
        perform {
            guard mayConnect(), let pair else { throw SyncError.notPaired }
            let state = try store.state()
            let hello = SyncHello(
                pairID: pair.pairID, deviceID: state.deviceID, name: Self.deviceName,
                baselineDigest: state.commonBaselineValid ? try state.baseline?.digest() : nil,
                pendingID: state.pending?.id, pendingApplied: state.pending?.applied ?? false,
                pendingDigest: try state.pending?.target.digest(),
                completedID: state.reports.first?.id)
            try send(SyncMessage(kind: .hello, hello: hello))
            armTimeout()
        }
    }

    private func receive(_ data: Data) {
        perform {
            guard mayConnect(), data.count <= SyncFrame.maximumSize else {
                throw SyncError.disconnected
            }
            let message = try JSONDecoder().decode(SyncMessage.self, from: data)
            if message.kind == .hello {
                guard peer == nil, let hello = message.hello else { throw SyncError.invalidData }
                try acceptHello(hello)
                return
            }
            guard peer != nil else { throw SyncError.notPaired }
            switch message.kind {
            case .request:
                guard canStart, let id = message.id, let snapshot = message.snapshot else {
                    throw SyncError.sessionPending
                }
                try checkSize(snapshot)
                remoteSnapshot = snapshot
                proposedSession = nil
                try SyncWriteGate.save(store.container.mainContext)
                requestID = id
                initiator = false
                localSnapshot = try store.snapshot()
                phase = .receiving
                try send(SyncMessage(kind: .snapshot, id: id, snapshot: localSnapshot))
                stageTimeout?.cancel()  // Human review is not a network timeout.
            case .snapshot:
                guard initiator, phase == .comparing, message.id == requestID,
                    let snapshot = message.snapshot, let localSnapshot
                else { throw SyncError.invalidData }
                try checkSize(snapshot)
                remoteSnapshot = snapshot
                let state = try store.state()
                let baseline = state.commonBaselineValid ? state.baseline : nil
                plan = try SyncMergePlanner.plan(
                    base: baseline, local: localSnapshot, remote: snapshot)
                choices = [:]
                phase = .review
                stageTimeout?.cancel()
                updatePreview()
            case .prepare:
                guard !initiator, phase == .receiving, message.id == requestID,
                    let target = message.snapshot, let expected = message.expectedDigest,
                    let other = message.otherDigest, let id = message.id
                else { throw SyncError.invalidData }
                try checkSize(target)
                guard let localSnapshot, let remoteSnapshot,
                    expected == (try localSnapshot.digest()),
                    other == (try remoteSnapshot.digest())
                else { throw SyncError.invalidData }
                let state = try store.state()
                let recomputed = try SyncMergePlanner.plan(
                    base: state.commonBaselineValid ? state.baseline : nil,
                    local: remoteSnapshot, remote: localSnapshot)
                guard let selections = message.choices,
                    try recomputed.finalized(selections).digest() == target.digest()
                else { throw SyncError.invalidData }
                try target.validateDeletions(from: localSnapshot.records + remoteSnapshot.records)
                guard try store.snapshot().digest() == expected else {
                    throw SyncError.stalePreview
                }
                proposedSession = SyncSession(
                    id: id, target: target, expectedLocalDigest: expected, applied: false,
                    expectedRemoteDigest: other)
                plan = SyncMergePlan(
                    automatic: target.records, conflicts: [],
                    deletedSeeds: target.deletedSeeds, aliases: target.aliases,
                    sourceRecords: localSnapshot.records + remoteSnapshot.records)
                choices = [:]
                phase = .review
                isPresented = true
                stageTimeout?.cancel()
                updatePreview()
            case .prepared:
                guard initiator, let id = message.id, id == requestID else {
                    throw SyncError.invalidData
                }
                try commit(id)
                try send(SyncMessage(kind: .commit, id: id))
                armTimeout()
            case .commit:
                guard let id = message.id else { throw SyncError.invalidData }
                let state = try store.state()
                guard state.pending?.id == id || state.reports.contains(where: { $0.id == id })
                else { throw SyncError.invalidData }
                try commit(id)
                try send(SyncMessage(kind: .committed, id: id))
                armTimeout()
            case .committed:
                let currentState = try store.state()
                guard let id = message.id,
                    currentState.pending?.id == id
                        || currentState.reports.contains(where: { $0.id == id })
                else { throw SyncError.invalidData }
                try store.complete(id)
                refresh()
                try send(SyncMessage(kind: .complete, id: id))
                armTimeout()
            case .complete:
                guard let id = message.id else { throw SyncError.invalidData }
                try store.complete(id)
                refresh()
                try send(SyncMessage(kind: .finished, id: id))
                finished()
            case .finished:
                guard let id = message.id,
                    try store.state().reports.contains(where: { $0.id == id })
                else { throw SyncError.invalidData }
                finished()
            case .cancel:
                guard let id = message.id else { throw SyncError.invalidData }
                if let pending = try store.state().pending {
                    guard pending.id == id, !pending.applied else { throw SyncError.sessionPending }
                    try store.abandonPreparedSession()
                } else {
                    guard id == requestID || id == peer?.pendingID else {
                        throw SyncError.invalidData
                    }
                }
                refresh()
                resetReview()
            case .failure: throw SyncError.disconnected
            case .hello: throw SyncError.invalidData
            }
        }
    }

    private func acceptHello(_ hello: SyncHello) throws {
        guard let pair, hello.version == 1, hello.flavour == .current,
            hello.pairID == pair.pairID, hello.name.count <= 256
        else { throw SyncError.incompatiblePeer }
        let state = try store.state()
        guard hello.deviceID != state.deviceID,
            state.peerID == nil || state.peerID == hello.deviceID,
            state.deviceID == pair.hostID || hello.deviceID == pair.hostID
        else { throw SyncError.incompatiblePeer }
        peer = hello
        peerName = hello.name
        pairingCode = nil
        try store.updateState {
            $0.peerID = hello.deviceID
            $0.peerName = hello.name
        }
        phase = .connected
        stageTimeout?.cancel()
        // Only the host coordinates recovery, avoiding two simultaneous commits.
        if state.pending != nil || hello.pendingID != nil {
            phase = .applying
            if state.deviceID == pair.hostID { try recover(local: state, remote: hello) }
            if phase == .applying { armTimeout() }
            return
        }
        let ownBase = state.commonBaselineValid ? try state.baseline?.digest() : nil
        guard ownBase == hello.baselineDigest else { throw SyncError.incompatiblePeer }
        refresh()
    }

    private func recover(local: SyncLocalState, remote: SyncHello) throws {
        if let pending = local.pending {
            requestID = pending.id
            initiator = true
            if remote.pendingID == pending.id {
                guard remote.pendingDigest == (try pending.target.digest()) else {
                    throw SyncError.invalidData
                }
                try commit(pending.id)
                try send(SyncMessage(kind: .commit, id: pending.id))
            } else if remote.pendingID == nil, remote.completedID == pending.id,
                remote.baselineDigest == (try pending.target.digest())
            {
                try commit(pending.id)
                try store.complete(pending.id)
                try send(SyncMessage(kind: .complete, id: pending.id))
            } else if remote.pendingID == nil, !pending.applied {
                try store.abandonPreparedSession()
                try send(SyncMessage(kind: .cancel, id: pending.id))
                refresh()
                resetReview()
            } else {
                throw SyncError.sessionPending
            }
        } else if let remoteID = remote.pendingID {
            requestID = remoteID
            if local.reports.contains(where: { $0.id == remoteID }), remote.pendingApplied {
                try send(SyncMessage(kind: .complete, id: remoteID))
            } else if !remote.pendingApplied {
                try send(SyncMessage(kind: .cancel, id: remoteID))
                resetReview()
            } else {
                throw SyncError.sessionPending
            }
        }
    }

    private func commit(_ id: UUID) throws {
        setLocked(true)
        try store.commit(id)
        contentRevision += 1
        onApplied?()
        refresh()
        phase = .applying
    }

    private func finished() {
        stageTimeout?.cancel()
        refresh()
        phase = .complete
        errorMessage = nil
        plan = nil
        requestID = nil
        if var hello = peer {
            hello.baselineDigest = try? store.state().baseline?.digest()
            hello.pendingID = nil
            peer = hello
        }
    }

    private func resetReview() {
        stageTimeout?.cancel()
        plan = nil
        proposedSession = nil
        requestID = nil
        localSnapshot = nil
        remoteSnapshot = nil
        choices = [:]
        previewLocal = []
        previewRemote = []
        phase = peer == nil ? .idle : .connected
    }

    private func setLocked(_ locked: Bool) {
        writesLocked = locked
        if locked {
            SyncWriteGate.lock(store.container)
        } else {
            SyncWriteGate.unlock(store.container)
        }
    }

    func displayValue(_ value: SyncValue, field: String) -> String {
        if field == "incomeAllocationSnapshot", let encoded = value.text,
            let snapshot = try? IncomeAllocationSnapshotCodec.decode(encoded)
        {
            return snapshot.slices.map {
                $0.name + ": " + NSDecimalNumber(decimal: $0.amount).stringValue
            }.joined(separator: "; ")
        }
        if let text = value.text, field.hasSuffix("ID"), UUID(uuidString: text) != nil {
            let records = (localSnapshot?.records ?? []) + (remoteSnapshot?.records ?? [])
            let names = Array(Set(records.filter { $0.uuid == text.lowercased() }.map(\.title)))
                .sorted()
            if !names.isEmpty { return names.joined(separator: " / ") }
        }
        if let text = value.text, let date = try? MonMonBackupScalar.parseDate(text) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return SyncLabels.value(value)
    }

    private func checkSize(_ snapshot: SyncSnapshot) throws {
        guard try SyncCoding.encode(snapshot).count <= MonMonBackupValidator.maximumByteCount else {
            throw SyncError.tooLarge
        }
    }

    private func send(_ message: SyncMessage) throws {
        if let snapshot = message.snapshot { try checkSize(snapshot) }
        try transport.send(SyncCoding.encode(message))
    }

    private func armTimeout() {
        stageTimeout?.cancel()
        stageTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.fail(SyncError.disconnected)
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { fail(error) }
    }

    private func fail(_ error: Error) {
        // Leave a validation error in the review so the owner can change a choice.
        if phase == .review
            && (error as? SyncError == .missingReferences || error is MonMonBackupValidationError
                || error as? SyncError == .unresolvedConflicts)
        {
            errorMessage = error.localizedDescription
            return
        }
        transport.stop()
        stageTimeout?.cancel()
        peer = nil
        pairingCode = nil
        errorMessage = error.localizedDescription
        refresh()
        phase = .interrupted
    }

    private static var deviceName: String {
        #if os(iOS)
            return String(UIDevice.current.name.prefix(256))
        #else
            return String((Host.current().localizedName ?? "Mac").prefix(256))
        #endif
    }
}
