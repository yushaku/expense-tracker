import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("P2P durable session")
@MainActor
struct SyncSessionTests {
    @Test("A new store never inherits the lock of a retired container")
    func retiredStoreLocks() throws {
        for _ in 0..<20 {
            try autoreleasepool {
                let container = try ModelContainer(
                    for: Schema(MonMonSchema.models),
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
                #expect(!SyncWriteGate.isLocked(container))
                SyncWriteGate.lock(container)
                #expect(SyncWriteGate.isLocked(container))
                #expect(throws: SyncError.sessionPending) {
                    try SyncWriteGate.save(container.mainContext)
                }
                // Simulate closing a store while its durable session is pending.
                // Its replacement must inspect its own metadata to acquire a lock.
            }
        }
    }

    private func store() throws -> SyncSessionStore {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        AccountSeed.ensureUnassignedExists(in: container.mainContext)
        return SyncSessionStore(
            container: container,
            researchStore: ResearchNotebookStore(
                directory: FileManager.default.temporaryDirectory.appending(
                    path: "ResearchSyncTest-\(UUID())")),
            recoveryDirectory: FileManager.default.temporaryDirectory.appending(
                path: UUID().uuidString))
    }

    private func researchFixture() throws -> ResearchNotebook {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let note = ResearchNote(
            id: UUID(), title: "Research", content: "Source-backed draft",
            sources: [
                ResearchSource(
                    title: "Source", url: try #require(URL(string: "https://example.com")),
                    accessedAt: now)
            ],
            instrumentID: nil, researchedAt: now, reviewAfter: now.addingTimeInterval(86400),
            createdAt: now)
        let proposal = InvestmentProposal(
            id: UUID(), title: "Save", action: .saveCash,
            target: "Savings", amount: "100", currencyCode: "VND", rationale: "Reserve",
            risks: "Liquidity", assumptions: "Stable income", alternatives: "Cash",
            noteIDs: [note.id], financialDataReadAt: now, validUntil: now.addingTimeInterval(86400),
            createdAt: now)
        return ResearchNotebook(notes: [note], proposals: [proposal])
    }

    private func apply(_ target: SyncSnapshot, to store: SyncSessionStore) throws {
        let session = SyncSession(
            id: UUID(), target: target,
            expectedLocalDigest: try store.snapshot().digest(), applied: false)
        try store.prepare(session)
        try store.commit(session.id)
        try store.complete(session.id)
    }

    @Test("Research syncs to another device and concurrent decisions return without losing history")
    func researchRoundTrip() throws {
        let mac = try store(), phone = try store()
        let notebook = try researchFixture()
        try mac.notebookStore().update { $0 = notebook }
        let target = try SyncMergePlanner.plan(
            base: nil, local: mac.snapshot(), remote: phone.snapshot()
        ).finalized([:])
        try apply(target, to: mac)
        try apply(target, to: phone)
        #expect(try phone.notebookStore().load().notes == notebook.notes)
        let proposal = try #require(notebook.proposals.first)
        let instant = proposal.createdAt.addingTimeInterval(10)
        try mac.notebookStore().decide(
            proposalID: proposal.id, decision: .deferred, reason: "Wait", now: instant)
        try phone.notebookStore().decide(
            proposalID: proposal.id, decision: .accepted, reason: "Reviewed", now: instant)
        let next = try SyncMergePlanner.plan(
            base: target, local: mac.snapshot(), remote: phone.snapshot()
        ).finalized([:])
        try apply(next, to: mac)
        try apply(next, to: phone)
        let left = try mac.notebookStore().load(), right = try phone.notebookStore().load()
        #expect(left == right)
        #expect(left.decisions.count == 2)
        #expect(left.decision(for: proposal) == right.decision(for: proposal))
        #expect(try mac.state().reports.first?.added == 1)
    }

    @Test("An agent write after preview prevents committing stale research")
    func staleResearchPreview() throws {
        let store = try store()
        let before = try store.snapshot()
        let session = SyncSession(
            id: UUID(), target: before,
            expectedLocalDigest: try before.digest(), applied: false)
        try store.prepare(session)
        let notebook = try researchFixture()
        try store.notebookStore().update { $0 = notebook }
        #expect(throws: SyncError.stalePreview) { try store.commit(session.id) }
        #expect(try store.notebookStore().load() == notebook)
        #expect(try store.state().pending?.applied == false)
    }

    @Test("Recovery finishes notebook writing after the financial receipt, preserving newer data")
    func recoverResearchWrite() throws {
        let store = try store()
        var target = try store.snapshot()
        let research = try researchFixture()
        try target.includeResearch(research)
        let session = SyncSession(
            id: UUID(), target: target,
            expectedLocalDigest: try store.snapshot().digest(), applied: false)
        try store.prepare(session)
        // Simulate the durable financial receipt with the notebook replacement interrupted.
        try store.updateState { $0.pending?.applied = true }
        let newer = try researchFixture()
        try store.notebookStore().update { $0 = newer }
        let account = try #require(
            store.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
        account.name = "Newer financial edit"
        try store.container.mainContext.save()
        try store.complete(session.id)
        let merged = try store.notebookStore().load()
        #expect(Set(merged.notes.map(\.id)) == Set((research.notes + newer.notes).map(\.id)))
        #expect(
            try store.snapshot().records.first { $0.type == "accounts" }?.fields["name"]
                == .string("Newer financial edit"))
        #expect(try store.state().pending == nil)
        try store.commit(session.id)
        #expect(try store.notebookStore().load() == merged)
    }

    @Test("Research validation rejects missing references and preserves append-only records")
    func validateResearch() throws {
        let store = try store()
        var snapshot = try store.snapshot()
        let notebook = try researchFixture()
        try snapshot.includeResearch(notebook)
        _ = try snapshot.validated()
        var conflicting = snapshot
        let index = try #require(conflicting.records.firstIndex { $0.type == "researchNotes" })
        conflicting.records[index].fields["title"] = .string("Other device research")
        let plan = try SyncMergePlanner.plan(base: nil, local: snapshot, remote: conflicting)
        #expect(plan.conflicts.count == 1)
        let conflict = try #require(plan.conflicts.first)
        #expect(throws: SyncError.unresolvedConflicts) { try plan.finalized([:]) }
        let resolved = try plan.finalized([conflict.id: 1])
        #expect(try resolved.researchNotebook().notes.first?.title == "Other device research")
        var unsafe = snapshot
        unsafe.records[index].fields["sources"] = .array([
            .object([
                "title": .string("Unsafe"), "url": .string("file:///tmp/local"),
                "accessedAt": .number(0),
            ])
        ])
        #expect(throws: SyncError.invalidData) { try unsafe.validated() }
        var invalid = snapshot
        invalid.records.removeAll { $0.type == "researchNotes" }
        #expect(throws: SyncError.invalidData) { try invalid.validated() }
        var absent = snapshot
        absent.records.removeAll { SyncSnapshot.researchTypes.contains($0.type) }
        let merged = try SyncMergePlanner.plan(base: snapshot, local: snapshot, remote: absent)
            .finalized([:])
        #expect(try merged.researchNotebook() == notebook)
    }

    @Test("Committing the same session twice preserves subsequent edits")
    func retryDoesNotOverwriteNewEdits() throws {
        let store = try store()
        let initial = try store.snapshot()
        let session = SyncSession(
            id: UUID(), target: initial, expectedLocalDigest: try initial.digest(), applied: false)
        try store.prepare(session)
        #expect(throws: SyncError.sessionPending) { try store.complete(session.id) }
        try store.commit(session.id)
        let context = store.container.mainContext
        let account = try #require(context.fetch(FetchDescriptor<CashAccount>()).first)
        account.name = "Edited after commit"
        try context.save()
        try store.commit(session.id)
        #expect(
            try store.snapshot().records.first?.fields["name"] == .string("Edited after commit"))
        #expect(try store.state().pending?.applied == true)
        account.name = "Unsaved edit after commit"
        try store.commit(session.id)
        #expect(account.name == "Unsaved edit after commit")
        #expect(context.hasChanges)
    }

    @Test("Changed data invalidates a prepared preview")
    func stalePreview() throws {
        let store = try store()
        let initial = try store.snapshot()
        let session = SyncSession(
            id: UUID(), target: initial, expectedLocalDigest: try initial.digest(), applied: false)
        let account = try #require(
            store.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
        account.name = "Changed"
        try store.container.mainContext.save()
        #expect(throws: SyncError.stalePreview) { try store.prepare(session) }
        #expect(try store.state().pending == nil)
    }

    @Test("Local drafts are not part of a sync snapshot")
    func draftsRemainLocal() throws {
        let store = try store()
        let before = try store.snapshot()
        let draft = PendingTransactionCapture(
            id: UUID(), rawText: "private", kind: .expense, amount: nil, occurredAt: .now, note: "",
            accountID: nil, categoryID: nil, issueCodes: "", createdAt: .now)
        store.container.mainContext.insert(draft)
        try store.container.mainContext.save()
        #expect(try store.snapshot().digest() == before.digest())
        let session = SyncSession(
            id: UUID(), target: before, expectedLocalDigest: try before.digest(), applied: false)
        try store.prepare(session)
        try store.commit(session.id)
        #expect(
            try store.container.mainContext.fetchCount(FetchDescriptor<PendingTransactionCapture>())
                == 1)
    }
    @Test("An unavailable recovery destination prevents preparation without changing data")
    func backupFailure() throws {
        let original = try store()
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("file, not directory".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let blocked = SyncSessionStore(
            container: original.container, researchStore: try original.notebookStore(),
            recoveryDirectory: file)
        let snapshot = try blocked.snapshot()
        let session = SyncSession(
            id: UUID(), target: snapshot, expectedLocalDigest: try snapshot.digest(), applied: false
        )
        #expect(throws: SyncError.backupFailed) { try blocked.prepare(session) }
        #expect(try blocked.state().pending == nil)
        #expect(try blocked.snapshot().digest() == snapshot.digest())
    }

    @Test("Pending receipts survive closing and reopening the on-disk store")
    func persistentReceipt() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "data.store")
        func open() throws -> SyncSessionStore {
            let schema = Schema(MonMonSchema.models)
            let configuration = ModelConfiguration(
                schema: schema, url: url, cloudKitDatabase: .none)
            return SyncSessionStore(
                container: try ModelContainer(for: schema, configurations: configuration),
                researchStore: ResearchNotebookStore(
                    directory: directory.appending(path: "research")),
                recoveryDirectory: directory.appending(path: "backups"))
        }
        let sessionID = UUID()
        do {
            let original = try open()
            AccountSeed.ensureUnassignedExists(in: original.container.mainContext)
            let snapshot = try original.snapshot()
            try original.prepare(
                SyncSession(
                    id: sessionID, target: snapshot, expectedLocalDigest: try snapshot.digest(),
                    applied: false))
        }
        do {
            let reopened = try open()
            #expect(try reopened.state().pending?.id == sessionID)
            #expect(try reopened.state().pending?.applied == false)
            try reopened.commit(sessionID)
        }
        do {
            let reopened = try open()
            #expect(try reopened.state().pending?.applied == true)
            let account = try #require(
                reopened.container.mainContext.fetch(FetchDescriptor<CashAccount>()).first)
            account.name = "Changed after restart"
            try reopened.container.mainContext.save()
            try reopened.commit(sessionID)
            #expect(
                try reopened.snapshot().records.first?.fields["name"]
                    == .string("Changed after restart"))
            try reopened.complete(sessionID)
            #expect(try reopened.state().reports.first?.id == sessionID)
        }
    }

    @Test("Local preference references follow aliases without importing settings")
    func preferenceReferences() throws {
        let suite = "SyncLocalReferences-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let old = UUID(), new = UUID(), removed = UUID()
        defaults.set(old.uuidString, forKey: TransactionDefaults.categoryStorageKey)
        defaults.set(removed.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set("private preference", forKey: "unrelated")
        let presets = QuickExpensePresetStore(defaults: defaults)
        var entries = QuickExpensePreset.defaults
        entries[0] = try QuickExpensePreset(
            slot: .coffee, symbol: "🍵", amount: 42000, categoryID: old)
        try presets.save(QuickExpenseConfiguration(visibleCount: 3, presets: entries))
        let snapshot = SyncSnapshot(
            records: [
                SyncRecord(type: "categories", fields: ["id": .string(new.uuidString.lowercased())])
            ],
            aliases: [
                "categories/" + old.uuidString.lowercased(): "categories/"
                    + new.uuidString.lowercased()
            ])
        try SyncLocalReferences.reconcile(snapshot, defaults: defaults, presets: presets)
        #expect(defaults.string(forKey: TransactionDefaults.categoryStorageKey) == new.uuidString)
        #expect(defaults.string(forKey: TransactionDefaults.accountStorageKey) == nil)
        #expect(defaults.string(forKey: "unrelated") == "private preference")
        #expect(presets.load().presets[0].categoryID == new)
        #expect(presets.load().presets[0].amount == 42000)
        #expect(presets.load().visibleCount == 3)
    }

    @Test("Startup preserves conflicting duplicate rows before first pairing")
    func initialDuplicatesSurviveStartup() throws {
        let store = try store()
        _ = try store.state()
        let context = store.container.mainContext
        let original = try #require(context.fetch(FetchDescriptor<CashAccount>()).first)
        let duplicate = CashAccount(
            id: original.id, name: "Conflicting version", kind: original.kind,
            openingBalance: 999, currencyCode: original.currencyCode, createdAt: .now)
        context.insert(duplicate)
        try context.save()
        #expect(try StoreReconciler.reconcile(in: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<CashAccount>()) == 2)
        let plan = try SyncMergePlanner.plan(base: nil, local: store.snapshot(), remote: .empty)
        #expect(plan.conflicts.count == 1)
    }

}
