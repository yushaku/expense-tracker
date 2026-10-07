import Foundation
import SwiftData

struct SyncSession: Codable, Equatable, Sendable {
    var id: UUID
    var target: SyncSnapshot
    var expectedLocalDigest: String
    var applied: Bool
    var expectedRemoteDigest: String = ""
    var startedAt: Date = .now
    // Older pending sessions lack this snapshot and retain their write lock until recovered.
    var localAtPreparation: SyncSnapshot?
    var researchAtCommit: ResearchNotebook?
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
    private let researchStore: ResearchNotebookStore?
    private static let key = "sync/state"

    init(
        container: ModelContainer, researchStore: ResearchNotebookStore? = nil,
        recoveryDirectory: URL? = nil
    ) {
        self.container = container
        self.researchStore = researchStore
        self.recoveryDirectory =
            recoveryDirectory
            ?? MonMonBackupService.defaultRecoveryURL.deletingLastPathComponent().appending(
                path: "p2p-recovery", directoryHint: .isDirectory
            ).appending(path: MonMonBackupFlavour.current.rawValue)
    }

    func notebookStore() throws -> ResearchNotebookStore {
        try researchStore ?? ResearchNotebookStore.current()
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
        try snapshot.includeResearch(notebookStore().load())
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
        let local = try snapshot()
        guard try local.digest() == session.expectedLocalDigest else {
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
            let researchData = try SyncCoding.encode(notebookStore().load())
            try researchData.write(
                to: recoveryDirectory.appending(path: session.id.uuidString + ".research.json"),
                options: .atomic)
            #if os(iOS)
                try data.write(to: recoveryURL, options: [.atomic, .completeFileProtection])
            #else
                try data.write(to: recoveryURL, options: .atomic)
            #endif
        } catch { throw SyncError.backupFailed }
        var prepared = session
        prepared.localAtPreparation = local
        try updateState { $0.pending = prepared }
    }

    /// Financial data and its receipt share one save. The notebook is locked across
    /// that save; if its atomic file replacement fails, the persisted receipt lets
    /// retry finish research without replaying financial data or losing new decisions.
    func commit(_ sessionID: UUID) throws {
        var state = try state()
        guard var pending = state.pending, pending.id == sessionID else {
            if state.reports.contains(where: { $0.id == sessionID }) { return }
            throw SyncError.sessionPending
        }
        var appliedFinancialData = false
        defer {
            if appliedFinancialData {
                // Also invalidate stale editors when the later notebook write fails.
                container.mainContext.rollback()
                GoalWidgetSnapshot.refresh(in: ModelContext(container))
                WidgetTodayExpenses.refresh(in: ModelContext(container))
            }
        }
        try notebookStore().update { notebook in
            if pending.applied {
                try notebook.mergeReviewed(
                    pending.researchAtCommit ?? pending.target.researchNotebook())
                return
            }
            // A form may have opened while the peer was preparing. Never roll its
            // unsaved context back; recover after the form has saved or closed.
            guard !container.mainContext.hasChanges else { throw SyncError.stalePreview }
            let current = try snapshot()
            let result = try preservingLaterEdits(in: current, session: pending)
            var merged = notebook
            try merged.mergeReviewed(result.researchNotebook())
            let payload = try result.validated()
            let context = ModelContext(container)
            context.autosaveEnabled = false
            do {
                try MonMonBackupService(container: container).apply(
                    payload, in: context, includeDeviceData: false)
                try remapLocalDrafts(result, in: context)
                for type in ["categories", "budgetJars", "defaultBank", "migration"] {
                    try SeedState.mark(type, in: context)
                }
                pending.applied = true
                pending.researchAtCommit = try result.researchNotebook()
                state.pending = pending
                state.baseline = pending.target
                state.commonBaselineValid = true
                try write(state, in: context)
                try context.save()
                appliedFinancialData = true
            } catch {
                context.rollback()
                throw error
            }
            notebook = merged
        }
    }

    /// Writes after preparation are later local edits, just like writes after a
    /// successful commit. Replay them over the agreed target, keeping that target
    /// as the common baseline so the next sync transmits these edits to the peer.
    private func preservingLaterEdits(in current: SyncSnapshot, session: SyncSession) throws
        -> SyncSnapshot
    {
        if try current.digest() == session.expectedLocalDigest { return session.target }
        guard let original = session.localAtPreparation,
            try original.digest() == session.expectedLocalDigest
        else { throw SyncError.stalePreview }
        var plan = try SyncMergePlanner.plan(base: original, local: current, remote: session.target)
        let originals = Dictionary(
            grouping: original.records.map {
                SyncMergePlanner.remap($0, aliases: plan.aliases)
            }, by: \.id)
        let choicesForLocal = plan.preferredChoices(origin: "This device")
        for index in plan.conflicts.indices {
            let conflict = plan.conflicts[index]
            guard let localIndex = choicesForLocal[conflict.id],
                let local = conflict.options[localIndex],
                let remoteIndex = conflict.origins.firstIndex(of: "Other device"),
                var remote = conflict.options[remoteIndex],
                let old = originals[conflict.id], old.count == 1
            else { continue }
            // Replay only fields actually edited since preparation; keep independent
            // incoming edits to the other fields of the same record.
            for field in Set(old[0].fields.keys).union(local.fields.keys)
            where old[0].fields[field] != local.fields[field] {
                remote.fields[field] = local.fields[field]
            }
            plan.conflicts[index].options[localIndex] = remote
        }
        var choices = choicesForLocal
        for conflict in plan.conflicts where choices[conflict.id] == nil {
            // A newly added child can still need a parent deleted by the agreed
            // target. Keep that parent locally along with the later child edit.
            if let keep = conflict.origins.firstIndex(of: "Keep referenced item") {
                choices[conflict.id] = keep
            }
        }
        return try plan.finalized(choices)
    }

    func complete(_ sessionID: UUID) throws {
        let current = try state()
        guard current.pending?.id == sessionID, current.pending?.applied == true else {
            if current.reports.contains(where: { $0.id == sessionID }) { return }
            throw SyncError.sessionPending
        }
        try commit(sessionID)
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
            let researchURL = recoveryDirectory.appending(
                path: sessionID.uuidString + ".research.json")
            if let data = try? Data(contentsOf: researchURL),
                let notebook = try? JSONDecoder().decode(ResearchNotebook.self, from: data)
            {
                try before.includeResearch(notebook)
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
        GoalWidgetSnapshot.refresh(in: context)
        WidgetTodayExpenses.refresh(in: context)
    }
}
