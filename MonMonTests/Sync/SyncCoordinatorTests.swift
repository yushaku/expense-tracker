import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
private final class TestSyncTransport: PeerSyncTransport {
    var onConnected: (() -> Void)?
    var onMessage: ((Data) -> Void)?
    var onError: ((Error) -> Void)?
    var outbox: [Data] = []
    var started = false
    func start(pairing: SyncPairing, isHost: Bool) throws { started = true }
    func send(_ data: Data) throws {
        guard started else { throw SyncError.disconnected }
        outbox.append(data)
    }
    func stop() {
        started = false
        outbox = []
    }
}

@Suite("P2P two-device protocol")
@MainActor
struct SyncCoordinatorTests {
    private func store() throws -> SyncSessionStore {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        // Each fixture is a new store. A prior fixture can leave a write-gate
        // identifier behind that this allocation reuses.
        SyncWriteGate.unlock(container)
        container.mainContext.autosaveEnabled = false
        AccountSeed.ensureUnassignedExists(in: container.mainContext)
        return SyncSessionStore(
            container: container,
            recoveryDirectory: FileManager.default.temporaryDirectory.appending(
                path: UUID().uuidString))
    }

    private func drain(
        _ a: TestSyncTransport, _ b: TestSyncTransport, drop: SyncMessage.Kind? = nil
    ) throws {
        for _ in 0..<40 {
            let first = a.outbox
            a.outbox = []
            let second = b.outbox
            b.outbox = []
            if first.isEmpty && second.isEmpty { return }
            for data in first
            where try JSONDecoder().decode(SyncMessage.self, from: data).kind != drop {
                b.onMessage?(data)
            }
            for data in second
            where try JSONDecoder().decode(SyncMessage.self, from: data).kind != drop {
                a.onMessage?(data)
            }
        }
        Issue.record("Protocol did not become idle")
    }

    private func connect(
        _ a: SyncCoordinator, _ b: SyncCoordinator, _ ta: TestSyncTransport, _ tb: TestSyncTransport
    ) throws {
        a.connect()
        b.connect()
        ta.onConnected?()
        tb.onConnected?()
        try drain(ta, tb)
    }

    @Test("Initial union and repeated sync converge without changing local drafts")
    func fullSession() throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        let account = CashAccount(
            id: UUID(), name: "Personal", kind: .normal, openingBalance: 100, currencyCode: "VND",
            createdAt: .now)
        a.container.mainContext.insert(account)
        try a.container.mainContext.save()
        try connect(ca, cb, ta, tb)
        #expect(ca.canStart && cb.canStart)
        ca.startSync()
        try drain(ta, tb)
        #expect(ca.canApply)
        ca.apply()
        try drain(ta, tb)
        #expect(cb.canApply)
        #expect(try b.state().pending == nil)
        #expect(try b.snapshot().records.count == 1)
        cb.apply()
        try drain(ta, tb)
        #expect(ca.phase == .complete, "\(ca.errorMessage ?? "")")
        #expect(cb.phase == .complete, "\(cb.errorMessage ?? "")")
        #expect(try a.snapshot().digest() == b.snapshot().digest())
        #expect(try b.snapshot().records.count == 2)
        cb.startSync()
        try drain(ta, tb)
        #expect(cb.previewLocal.isEmpty && cb.previewRemote.isEmpty)
        cb.apply()
        try drain(ta, tb)
        ca.apply()
        try drain(ta, tb)
        #expect(try a.state().reports.count == 2)
        #expect(try b.state().reports.count == 2)
    }

    @Test(
        "Conflicts prefer iPhone regardless of the initiator and remain editable",
        arguments: [false, true])
    func prefersPhoneVersion(phoneInitiates: Bool) throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let macAccount = try #require(
            a.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
        let phoneAccount = try #require(
            b.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
        macAccount.name = "Mac version"
        phoneAccount.name = "iPhone version"
        try a.container.mainContext.save()
        try b.container.mainContext.save()
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        let initiator = phoneInitiates ? cb : ca
        let responder = phoneInitiates ? ca : cb
        initiator.startSync()
        try drain(ta, tb)
        let conflict = try #require(initiator.plan?.conflicts.first)
        let preferred = try #require(initiator.choices[conflict.id])
        #expect(conflict.options[preferred]?.fields["name"] == .string("iPhone version"))
        #expect(initiator.canApply)
        #expect(try a.state().pending == nil && b.state().pending == nil)
        let macIndex = try #require(
            conflict.options.firstIndex { $0?.fields["name"] == .string("Mac version") })
        initiator.choices[conflict.id] = macIndex
        initiator.updatePreview()
        initiator.apply()
        try drain(ta, tb)
        #expect(responder.canApply)
        #expect(phoneAccount.name == "iPhone version")
        responder.apply()
        try drain(ta, tb)
        #expect(ca.phase == .complete && cb.phase == .complete)
        #expect(try a.snapshot().records.first?.fields["name"] == .string("Mac version"))
        #expect(try a.snapshot().digest() == b.snapshot().digest())
    }

    @Test(
        "A failed review exposes reconnect without losing the pending session",
        arguments: [false, true])
    func reconnectAfterReviewFailure(phoneInitiates: Bool) throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        let initiator = phoneInitiates ? cb : ca
        let responder = phoneInitiates ? ca : cb
        let initiatorStore = phoneInitiates ? b : a
        let before = try initiatorStore.snapshot().digest()
        initiator.startSync()
        try drain(ta, tb)
        initiator.apply()
        try drain(ta, tb)
        #expect(responder.canApply)
        let pendingID = try #require(initiatorStore.state().pending?.id)

        // Use transport errors, without dismissing the sheet or recreating coordinators.
        ta.onError?(SyncError.disconnected)
        tb.onError?(SyncError.disconnected)
        #expect(initiator.phase == .interrupted)
        #expect(initiator.plan == nil)
        #expect(responder.plan == nil)
        #expect(initiator.hasPending && initiator.writesLocked)
        #expect(try initiatorStore.state().pending?.id == pendingID)
        #expect(try initiatorStore.state().pending?.applied == false)
        #expect(try initiatorStore.snapshot().digest() == before)

        try connect(ca, cb, ta, tb)
        #expect(ca.canStart && cb.canStart)
        #expect(!ca.writesLocked && !cb.writesLocked)
        #expect(try a.state().pending == nil)
        #expect(try b.state().pending == nil)
        initiator.startSync()
        try drain(ta, tb)
        initiator.apply()
        try drain(ta, tb)
        responder.apply()
        try drain(ta, tb)
        #expect(ca.phase == .complete && cb.phase == .complete)
        #expect(try a.snapshot().digest() == b.snapshot().digest())
    }

    @Test("Reconnect completes a session interrupted after only the initiator committed")
    func interruptedCommit() throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        ca.startSync()
        try drain(ta, tb)
        ca.apply()
        try drain(ta, tb)
        cb.apply()
        try drain(ta, tb, drop: .commit)
        #expect(try a.state().pending?.applied == true)
        #expect(try b.state().pending?.applied == false)
        ca.disconnect()
        cb.disconnect()
        let account = try #require(
            a.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
        account.name = "After interruption"
        try SyncWriteGate.save(a.container.mainContext)
        let ra = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let rb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ra, rb, ta, tb)
        #expect(try a.state().pending == nil)
        #expect(try b.state().pending == nil)
        #expect(try a.snapshot().records.first?.fields["name"] == .string("After interruption"))
        ra.startSync()
        try drain(ta, tb)
        #expect(ra.plan?.conflicts.isEmpty == true)
        ra.apply()
        try drain(ta, tb)
        rb.apply()
        try drain(ta, tb)
        #expect(try a.snapshot().digest() == b.snapshot().digest())
    }
    @Test(
        "Every interrupted protocol boundary can recover",
        arguments: [
            SyncMessage.Kind.prepare, .prepared, .commit, .committed, .complete, .finished,
        ], [false, true])
    func recoveryAtEveryBoundary(boundary: SyncMessage.Kind, phoneInitiates: Bool) throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        let initiator = phoneInitiates ? cb : ca
        initiator.startSync()
        try drain(ta, tb)
        initiator.apply()
        try drain(ta, tb, drop: boundary)
        let responder = phoneInitiates ? ca : cb
        if responder.canApply {
            responder.apply()
            try drain(ta, tb, drop: boundary)
        }
        ca.disconnect()
        cb.disconnect()
        let ra = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let rb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ra, rb, ta, tb)
        #expect(try a.state().pending == nil, "\(boundary): \(ra.errorMessage ?? "")")
        #expect(try b.state().pending == nil, "\(boundary): \(rb.errorMessage ?? "")")
        #expect(ra.canStart && rb.canStart, "\(boundary): \(ra.phase) / \(rb.phase)")
        ra.startSync()
        try drain(ta, tb)
        #expect(ra.canApply)
        ra.apply()
        try drain(ta, tb)
        rb.apply()
        try drain(ta, tb)
        #expect(ra.phase == .complete && rb.phase == .complete)
        #expect(try a.snapshot().digest() == b.snapshot().digest())
    }

    @Test(
        "A receiver can reject a proposal and an early commit cannot bypass consent",
        arguments: [false, true])
    func receiverConsent(earlyCommit: Bool) throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        let before = try b.snapshot().digest()
        ca.startSync()
        try drain(ta, tb)
        ca.apply()
        try drain(ta, tb)
        #expect(cb.canApply)
        #expect(try b.state().pending == nil)
        if earlyCommit {
            let id = try #require(a.state().pending?.id)
            tb.onMessage?(try SyncCoding.encode(SyncMessage(kind: .commit, id: id)))
            #expect(cb.phase == .interrupted)
        } else {
            cb.cancelReview()
            try drain(ta, tb)
            #expect(ca.canStart && cb.canStart)
            #expect(try a.state().pending == nil)
        }
        #expect(try b.snapshot().digest() == before)
        #expect(try b.state().pending == nil)
        ca.disconnect()
        cb.disconnect()
    }

    @Test(
        "The receiver rejects targets or hidden metadata outside the reviewed merge",
        arguments: ["records", "aliases", "seeds"])
    func rejectsTamperedProposal(field: String) throws {
        let a = try store(), b = try store()
        let pair = try SyncPairing.make(hostID: a.state().deviceID)
        try a.updateState { $0.pairID = pair.pairID }
        try b.updateState { $0.pairID = pair.pairID }
        let ta = TestSyncTransport(), tb = TestSyncTransport()
        let ca = SyncCoordinator(store: a, transport: ta, loadPairing: { _ in pair })
        let cb = SyncCoordinator(store: b, transport: tb, loadPairing: { _ in pair })
        try connect(ca, cb, ta, tb)
        let before = try b.snapshot().digest()
        ca.startSync()
        try drain(ta, tb)
        ca.apply()
        var message = try JSONDecoder().decode(SyncMessage.self, from: #require(ta.outbox.first))
        var target = try #require(message.snapshot)
        switch field {
        case "records": target.records[0].fields["name"] = .string("Unreviewed replacement")
        case "aliases":
            target.aliases["accounts/" + UUID().uuidString.lowercased()] = SyncSnapshot.anchorID
        default: target.deletedSeeds = []
        }
        message.snapshot = target
        ta.outbox = [try SyncCoding.encode(message)]
        try drain(ta, tb)
        #expect(cb.phase == .interrupted)
        #expect(!cb.canApply)
        #expect(try b.state().pending == nil)
        #expect(try b.snapshot().digest() == before)
        ca.disconnect()
        cb.disconnect()
    }

}
