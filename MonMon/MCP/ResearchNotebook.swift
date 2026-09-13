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
        decisions.last { $0.proposalID == proposal.id }
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
    case unavailable, incompatible, busy, capacity, duplicateID, missingReference, expired
}

/// A separate local notebook. Financial SwiftData stores are never opened for writing.
/// Atomic replacement and a process-wide file lock serialize app/helper changes.
struct ResearchNotebookStore: Sendable {
    static let maximumBytes = 20 * 1024 * 1024
    let directory: URL
    private var documentURL: URL { directory.appending(path: "notebook.json") }

    static func current(configuration: MCPRuntimeConfiguration) throws -> ResearchNotebookStore {
        guard
            let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: configuration.appGroupIdentifier)
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
        guard !trimmed.isEmpty, trimmed.count <= 2000 else { throw MCPToolError.invalidArgument }
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
