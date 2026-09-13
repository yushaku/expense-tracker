import Darwin
import Foundation

struct ResearchSource: Codable, Equatable, Identifiable, Sendable {
    let title: String
    let url: URL
    let accessedAt: Date
    var id: URL { url }
}

struct ResearchNote: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let content: String
    let sources: [ResearchSource]
    let instrumentID: UUID?
    let researchedAt: Date
    let reviewAfter: Date
    let createdAt: Date
}

enum InvestmentAction: String, Codable, CaseIterable, Sendable {
    case buyFund, saveCash, holdCash
}

struct InvestmentProposal: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let action: InvestmentAction
    let target: String
    let amount: String
    let currencyCode: String
    let rationale: String
    let risks: String
    let assumptions: String
    let alternatives: String
    let noteIDs: [UUID]
    let financialDataReadAt: Date
    let validUntil: Date
    let createdAt: Date
}

enum ResearchDecision: String, Codable, CaseIterable, Sendable {
    case accepted, deferred, rejected
}

struct DecisionRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let proposalID: UUID
    let decision: ResearchDecision
    let reason: String
    let createdAt: Date
}

struct ResearchNotebook: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var notes: [ResearchNote] = []
    var proposals: [InvestmentProposal] = []
    var decisions: [DecisionRecord] = []

    func decision(for proposal: InvestmentProposal) -> DecisionRecord? {
        decisions.filter { $0.proposalID == proposal.id }.max {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func needsReview(_ proposal: InvestmentProposal, now: Date = .now) -> Bool {
        proposal.validUntil <= now
            || proposal.noteIDs.contains { id in
                guard let note = notes.first(where: { $0.id == id }) else { return true }
                return note.reviewAfter <= now
            }
    }
}

enum ResearchStoreError: Error, Equatable {
    case unavailable, incompatible, busy, capacity, duplicateID, missingReference, expired,
        invalidArgument
}

/// A separate local notebook. Financial SwiftData stores are never opened for writing.
/// Atomic replacement and a process-wide file lock serialize app/helper changes.
struct ResearchNotebookStore: Sendable {
    static let maximumBytes = 20 * 1024 * 1024
    let directory: URL
    private var documentURL: URL { directory.appending(path: "notebook.json") }

    #if os(macOS)
        static func current(configuration: MCPRuntimeConfiguration) throws -> ResearchNotebookStore
        {
            guard
                let group = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: configuration.appGroupIdentifier)
            else { throw ResearchStoreError.unavailable }
            return ResearchNotebookStore(directory: group.appending(path: "ResearchNotebook"))
        }

    #endif

    static func current() throws -> ResearchNotebookStore {
        guard
            let identifier = Bundle.main.object(forInfoDictionaryKey: "MonMonAppGroupIdentifier")
                as? String,
            let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: identifier)
        else { throw ResearchStoreError.unavailable }
        return ResearchNotebookStore(directory: group.appending(path: "ResearchNotebook"))
    }

    func load() throws -> ResearchNotebook {
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            return ResearchNotebook()
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: documentURL.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= Self.maximumBytes else {
            throw ResearchStoreError.capacity
        }
        let notebook = try JSONDecoder().decode(
            ResearchNotebook.self, from: Data(contentsOf: documentURL))
        guard notebook.schemaVersion == 1 else { throw ResearchStoreError.incompatible }
        return notebook
    }

    @discardableResult
    func update<T>(_ mutation: (inout ResearchNotebook) throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(
            directory.appending(path: "write.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW,
            S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ResearchStoreError.unavailable }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw ResearchStoreError.busy }
        defer { flock(descriptor, LOCK_UN) }
        var notebook = try load()
        let result = try mutation(&notebook)
        let data = try JSONEncoder().encode(notebook)
        guard data.count <= Self.maximumBytes else { throw ResearchStoreError.capacity }
        try data.write(to: documentURL, options: .atomic)
        return result
    }

    func decide(proposalID: UUID, decision: ResearchDecision, reason: String, now: Date = .now)
        throws
    {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2000 else {
            throw ResearchStoreError.invalidArgument
        }
        try update { notebook in
            guard let proposal = notebook.proposals.first(where: { $0.id == proposalID }) else {
                throw ResearchStoreError.missingReference
            }
            guard decision != .accepted || !notebook.needsReview(proposal, now: now) else {
                throw ResearchStoreError.expired
            }
            notebook.decisions.append(
                DecisionRecord(
                    id: UUID(), proposalID: proposalID,
                    decision: decision, reason: trimmed, createdAt: now))
        }
    }
}

extension ResearchNotebook {
    /// Research records are append-only. A reviewed version replaces the same ID;
    /// new local records created after a sync commit are retained during recovery.
    mutating func mergeReviewed(_ other: ResearchNotebook) throws {
        func merged<T: Identifiable>(_ current: [T], _ incoming: [T]) -> [T] where T.ID == UUID {
            var values = Dictionary(firstWins: current.map { ($0.id, $0) })
            for value in incoming { values[value.id] = value }
            return Array(values.values)
        }
        notes = merged(notes, other.notes).sorted {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
        proposals = merged(proposals, other.proposals).sorted {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
        decisions = merged(decisions, other.decisions).sorted {
            $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
        try validateForSync()
    }

    func validateForSync() throws {
        func text(_ value: String, _ limit: Int) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= limit
        }
        func dates(_ values: Date...) -> Bool {
            values.allSatisfy { $0.timeIntervalSince1970.isFinite }
        }
        guard schemaVersion == 1,
            Set(notes.map(\.id)).count == notes.count,
            Set(proposals.map(\.id)).count == proposals.count,
            Set(decisions.map(\.id)).count == decisions.count
        else { throw SyncError.invalidData }
        let noteIDs = Set(notes.map(\.id)), proposalIDs = Set(proposals.map(\.id))
        for note in notes {
            guard text(note.title, 200), text(note.content, 20000),
                dates(note.createdAt, note.researchedAt, note.reviewAfter),
                note.reviewAfter > note.researchedAt, (1...10).contains(note.sources.count),
                Set(note.sources.map(\.url)).count == note.sources.count
            else { throw SyncError.invalidData }
            for source in note.sources {
                guard text(source.title, 200), source.url.absoluteString.count <= 2048,
                    ["https", "http"].contains(source.url.scheme?.lowercased() ?? ""),
                    source.url.host != nil, source.url.user == nil, source.url.password == nil,
                    dates(source.accessedAt)
                else { throw SyncError.invalidData }
            }
        }
        for proposal in proposals {
            guard text(proposal.title, 200), text(proposal.target, 200),
                [proposal.rationale, proposal.risks, proposal.assumptions, proposal.alternatives]
                    .allSatisfy({ text($0, 5000) }),
                proposal.currencyCode == "VND", proposal.amount.count <= 30,
                proposal.amount.range(of: "^[0-9]+(\\.[0-9]{1,8})?$", options: .regularExpression)
                    != nil,
                let amount = Decimal(
                    string: proposal.amount, locale: Locale(identifier: "en_US_POSIX")),
                amount > 0, amount <= 1_000_000_000_000_000_000,
                dates(proposal.createdAt, proposal.financialDataReadAt, proposal.validUntil),
                proposal.validUntil > proposal.financialDataReadAt,
                (1...20).contains(proposal.noteIDs.count),
                Set(proposal.noteIDs).count == proposal.noteIDs.count,
                Set(proposal.noteIDs).isSubset(of: noteIDs)
            else { throw SyncError.invalidData }
        }
        for decision in decisions {
            guard proposalIDs.contains(decision.proposalID), text(decision.reason, 2000),
                dates(decision.createdAt)
            else { throw SyncError.invalidData }
        }
        guard try JSONEncoder().encode(self).count <= ResearchNotebookStore.maximumBytes else {
            throw SyncError.tooLarge
        }
    }
}
