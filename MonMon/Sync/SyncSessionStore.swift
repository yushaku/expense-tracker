import Foundation
import SwiftData

struct SyncSession: Codable, Equatable, Sendable {
    var id: UUID
    var target: SyncSnapshot
    var expectedLocalDigest: String
    var applied: Bool
    var expectedRemoteDigest: String = ""
    var startedAt: Date = .now
}

struct SyncReport: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var completedAt: Date
    var peerName: String
    var added: Int
    var updated: Int
    var deleted: Int
}

struct SyncLocalState: Codable, Equatable, Sendable {
    var deviceID = UUID()
    var pairID: UUID?
    var peerID: UUID?
    var peerName = ""
    var baseline: SyncSnapshot?
    var commonBaselineValid = false
    var pending: SyncSession?
    var reports: [SyncReport] = []
}

@MainActor
struct SyncSessionStore {
    let container: ModelContainer
    let recoveryDirectory: URL
    private static let key = "sync/state"

    init(container: ModelContainer, recoveryDirectory: URL? = nil) {
        self.container = container
        self.recoveryDirectory =
            recoveryDirectory
            ?? MonMonBackupService.defaultRecoveryURL.deletingLastPathComponent().appending(
                path: "p2p-recovery", directoryHint: .isDirectory
            ).appending(path: MonMonBackupFlavour.current.rawValue)
    }

    func state() throws -> SyncLocalState {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if let row = try SyncMetadata.entry(Self.key, in: context) {
            return try JSONDecoder().decode(SyncLocalState.self, from: row.value)
        }
        let initial = SyncLocalState()
        try write(initial, in: context)
        try context.save()
        return initial
    }

    func updateState(_ update: (inout SyncLocalState) throws -> Void) throws {
        var state = try state()
        try update(&state)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try write(state, in: context)
        try context.save()
    }

    func snapshot() throws -> SyncSnapshot {
        let state = try state()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        var snapshot = try SyncSnapshot(payload: MonMonBackupService.snapshotPayload(in: context))
        snapshot.aliases = state.baseline?.aliases ?? [:]
        snapshot.deletedSeeds = state.baseline?.deletedSeeds ?? []
        let present = Set(snapshot.records.map(\.id))
        for (type, ids) in SyncSnapshot.seedIDs {
            let marker = type == "accounts" ? "defaultBank" : type
            if try SeedState.isInitialized(marker, in: context) {
                for id in ids where !present.contains(type + "/" + id) {
                    snapshot.deletedSeeds.insert(type + "/" + id)
                }
            }
        }
        snapshot.deletedSeeds.remove(SyncSnapshot.anchorID)
        return snapshot
    }

    func prepare(_ session: SyncSession) throws {
        let currentState = try state()
        if let pending = currentState.pending {
            guard pending.id == session.id, try pending.target.digest() == session.target.digest()
            else { throw SyncError.sessionPending }
            return
        }
        guard try snapshot().digest() == session.expectedLocalDigest else {
            throw SyncError.stalePreview
        }
        _ = try session.target.validated()
        try session.target.validateDeletions(
            from: snapshot().records.map {
                SyncMergePlanner.remap($0, aliases: session.target.aliases)
            })
        // The recovery copy is raw and lossless, including physical duplicates,
        // pending captures and preferences. It is never sent to the other device.
        do {
            let backup = MonMonBackupService(container: container)
            let payload = try backup.snapshotPayload()
            let document = try MonMonBackupDocument.make(
                payload: payload, exportedAt: .now, appVersion: "p2p-recovery-v1", flavour: .current
            )
            let data = try MonMonBackupCodec.encode(document)
            guard data.count <= MonMonBackupValidator.maximumByteCount else {
                throw SyncError.tooLarge
            }
            try FileManager.default.createDirectory(
                at: recoveryDirectory, withIntermediateDirectories: true)
            let recoveryURL = recoveryDirectory.appending(path: session.id.uuidString + ".json")
            #if os(iOS)
                try data.write(to: recoveryURL, options: [.atomic, .completeFileProtection])
            #else
                try data.write(to: recoveryURL, options: .atomic)
            #endif
        } catch { throw SyncError.backupFailed }
        try updateState { $0.pending = session }
    }

    /// Data and receipt share one save. Retrying an applied session never applies
    /// its old snapshot again, even if the owner has since made new edits.
    func commit(_ sessionID: UUID) throws {
        var state = try state()
        guard var pending = state.pending, pending.id == sessionID else {
            if state.reports.contains(where: { $0.id == sessionID }) { return }
            throw SyncError.sessionPending
        }
        guard !pending.applied else { return }
        guard try snapshot().digest() == pending.expectedLocalDigest else {
            throw SyncError.stalePreview
        }
        let payload = try pending.target.validated()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try MonMonBackupService(container: container).apply(
                payload, in: context, includeDeviceData: false)
            try remapLocalDrafts(pending.target, in: context)
            for type in ["categories", "budgetJars", "defaultBank", "migration"] {
                try SeedState.mark(type, in: context)
            }
            pending.applied = true
            state.pending = pending
            state.baseline = pending.target
            state.commonBaselineValid = true
            try write(state, in: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        // A main-context object loaded by an old editor must not save over the
        // incoming version. The app recreates its content tree after this call.
        container.mainContext.rollback()
    }

    func complete(_ sessionID: UUID) throws {
        try updateState { state in
            guard let pending = state.pending, pending.id == sessionID, pending.applied else {
                if state.reports.contains(where: { $0.id == sessionID }) { return }
                throw SyncError.sessionPending
            }
            let recovery = recoveryDirectory.appending(path: sessionID.uuidString + ".json")
            var before = SyncSnapshot.empty
            if let data = try? Data(contentsOf: recovery),
                let document = try? MonMonBackupCodec.decode(data)
            {
                before = (try? SyncSnapshot(payload: document.payload)) ?? .empty
            }
            let changes = try SyncMergePlan(
                automatic: pending.target.records, conflicts: [],
                deletedSeeds: pending.target.deletedSeeds, aliases: pending.target.aliases
            ).changes(from: before)
            state.reports.insert(
                SyncReport(
                    id: sessionID, completedAt: .now, peerName: state.peerName,
                    added: changes.filter { $0.before == nil }.count,
                    updated: changes.filter { $0.before != nil && $0.after != nil }.count,
                    deleted: changes.filter { $0.after == nil }.count), at: 0)
            state.reports = Array(state.reports.prefix(20))
            state.pending = nil
        }
    }

    func abandonPreparedSession() throws {
        try updateState { state in
            guard state.pending?.applied != true else { throw SyncError.sessionPending }
            state.pending = nil
        }
    }

    func recoveryFile(for id: UUID) -> URL? {
        let url = recoveryDirectory.appending(path: id.uuidString + ".json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func unpair() throws {
        try updateState { state in
            guard state.pending == nil else { throw SyncError.sessionPending }
            state.pairID = nil
            state.peerID = nil
            state.peerName = ""
            state.commonBaselineValid = false
            // Keep deleted-seed knowledge and identity aliases across re-pairing.
            // A new pair has no common baseline; the coordinator explicitly uses nil.
        }
    }

    static func invalidateAfterRestore(in context: ModelContext) throws {
        if let row = try SyncMetadata.entry(key, in: context) { context.delete(row) }
        for type in ["categories", "budgetJars", "defaultBank", "migration"] {
            try SeedState.mark(type, in: context)
        }
    }

    private func write(_ state: SyncLocalState, in context: ModelContext) throws {
        try SyncMetadata.set(Self.key, value: SyncCoding.encode(state), in: context)
    }

    private func remapLocalDrafts(_ snapshot: SyncSnapshot, in context: ModelContext) throws {
        let accounts = Set(snapshot.records.filter { $0.type == "accounts" }.map(\.uuid))
        let categories = Set(snapshot.records.filter { $0.type == "categories" }.map(\.uuid))
        for draft in try context.fetch(FetchDescriptor<PendingTransactionCapture>()) {
            func mapped(_ id: UUID?, type: String, valid: Set<String>) -> UUID? {
                guard let id else { return nil }
                let old = id.uuidString.lowercased()
                let new =
                    snapshot.aliases[type + "/" + old]?.split(separator: "/").last.map(String.init)
                    ?? old
                return valid.contains(new) ? UUID(uuidString: new) : nil
            }
            draft.accountID = mapped(draft.accountID, type: "accounts", valid: accounts)
            draft.categoryID = mapped(draft.categoryID, type: "categories", valid: categories)
        }
    }
}

/// All ordinary saves go through this gate. The sync adapter's short synchronous
/// transaction is the sole writer while a reviewed plan is being committed.
@MainActor
enum SyncWriteGate {
    // A retired container's address can be reused by a new store. Weak identity
    // tracking removes that lock with its owner instead of locking the new store.
    private static let locked = NSHashTable<ModelContainer>(options: [
        .weakMemory, .objectPointerPersonality,
    ])
    static func lock(_ container: ModelContainer) { locked.add(container) }
    static func unlock(_ container: ModelContainer) { locked.remove(container) }
    static func isLocked(_ container: ModelContainer) -> Bool {
        locked.contains(container)
    }
    static func save(_ context: ModelContext) throws {
        guard !isLocked(context.container) else {
            context.rollback()
            throw SyncError.sessionPending
        }
        try context.save()
    }
}
