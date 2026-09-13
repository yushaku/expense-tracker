import Foundation

/// Separate tool namespace: none of these methods can modify financial records or user decisions.
enum MCPResearchTool: String, CaseIterable, Sendable {
    case listNotes = "monmon_list_notes"
    case getNote = "monmon_get_note"
    case createNote = "monmon_create_research_note"
    case listProposals = "monmon_list_proposals"
    case getProposal = "monmon_get_proposal"
    case createProposal = "monmon_create_investment_proposal"

    var writes: Bool { self == .createNote || self == .createProposal }
}

@MainActor
final class MCPResearchService {
    static let writingAllowedKey = "MonMonMCPResearchWritingAllowed"
    private let store: () throws -> ResearchNotebookStore
    private let canRead: () -> Bool
    private let canWrite: () -> Bool
    private let now: () -> Date

    init(
        store: ResearchNotebookStore, canRead: @escaping () -> Bool,
        canWrite: @escaping () -> Bool, now: @escaping () -> Date = Date.init
    ) {
        self.store = { store }
        self.canRead = canRead
        self.canWrite = canWrite
        self.now = now
    }

    init(
        openStore: @escaping () throws -> ResearchNotebookStore, canRead: @escaping () -> Bool,
        canWrite: @escaping () -> Bool, now: @escaping () -> Date = Date.init
    ) {
        self.store = openStore
        self.canRead = canRead
        self.canWrite = canWrite
        self.now = now
    }

    func call(_ tool: MCPResearchTool, arguments: [String: MCPJSONValue]) throws -> MCPJSONValue {
        guard canRead() else { throw MCPToolError.disabled }
        guard !tool.writes || canWrite() else { throw MCPToolError.researchWritingDisabled }
        switch tool {
        case .createNote: return try createNote(arguments)
        case .createProposal: return try createProposal(arguments)
        case .getNote, .getProposal:
            try keys(arguments, required: ["id"])
            let id = try uuid(arguments, "id")
            let notebook = try store().load()
            if tool == .getNote {
                guard let note = notebook.notes.first(where: { $0.id == id }) else {
                    throw ResearchStoreError.missingReference
                }
                return try json(note)
            }
            guard let proposal = notebook.proposals.first(where: { $0.id == id }) else {
                throw ResearchStoreError.missingReference
            }
            return .object([
                "proposal": try json(proposal),
                "decisions": try json(notebook.decisions.filter { $0.proposalID == id }),
                "needsReview": .bool(notebook.needsReview(proposal, now: now())),
            ])
        case .listNotes, .listProposals:
            try keys(arguments, required: [], optional: ["limit", "offset"])
            let limit = try integer(arguments, "limit", default: 50, range: 1...100)
            let offset = try integer(arguments, "offset", default: 0, range: 0...100000)
            let notebook = try store().load()
            let values: [MCPJSONValue]
            if tool == .listNotes {
                values = notebook.notes.reversed().map { note in
                    .object([
                        "id": .string(note.id.uuidString.lowercased()),
                        "title": .string(note.title),
                        "reviewAfter": dateValue(note.reviewAfter),
                        "needsReview": .bool(note.reviewAfter <= now()),
                    ])
                }
            } else {
                values = notebook.proposals.reversed().map { proposal in
                    .object([
                        "id": .string(proposal.id.uuidString.lowercased()),
                        "title": .string(proposal.title),
                        "action": .string(proposal.action.rawValue),
                        "amount": .string(proposal.amount),
                        "status": .string(
                            notebook.decision(for: proposal)?.decision.rawValue ?? "draft"),
                        "needsReview": .bool(notebook.needsReview(proposal, now: now())),
                    ])
                }
            }
            let page = Array(values.dropFirst(offset).prefix(limit))
            return .object([
                "records": .array(page),
                "nextOffset": offset + page.count < values.count
                    ? .int(offset + page.count) : .null,
            ])
        }
    }

    private func createNote(_ args: [String: MCPJSONValue]) throws -> MCPJSONValue {
        try keys(
            args,
            required: ["requestID", "title", "content", "sources", "researchedAt", "reviewAfter"],
            optional: ["instrumentID"])
        let instant = now()
        let id = try uuid(args, "requestID")
        let researchedAt = try date(args, "researchedAt")
        let reviewAfter = try date(args, "reviewAfter")
        guard researchedAt <= instant.addingTimeInterval(60), reviewAfter > instant,
            reviewAfter > researchedAt, let sources = args["sources"]?.arrayValue,
            (1...10).contains(sources.count)
        else { throw MCPToolError.invalidArgument }
        let decodedSources = try sources.map { value -> ResearchSource in
            guard let fields = value.objectValue else { throw MCPToolError.invalidArgument }
            try keys(fields, required: ["title", "url", "accessedAt"])
            let raw = try string(fields, "url", maximum: 2048)
            guard let url = URL(string: raw),
                ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                url.host != nil, url.user == nil, url.password == nil
            else { throw MCPToolError.invalidArgument }
            let accessedAt = try date(fields, "accessedAt")
            guard accessedAt <= instant.addingTimeInterval(60) else {
                throw MCPToolError.invalidArgument
            }
            return ResearchSource(
                title: try string(fields, "title", maximum: 200), url: url, accessedAt: accessedAt)
        }
        guard Set(decodedSources.map(\.url)).count == decodedSources.count else {
            throw MCPToolError.invalidArgument
        }
        let note = ResearchNote(
            id: id, title: try string(args, "title", maximum: 200),
            content: try string(args, "content", maximum: 20000), sources: decodedSources,
            instrumentID: args["instrumentID"] == nil ? nil : try uuid(args, "instrumentID"),
            researchedAt: researchedAt, reviewAfter: reviewAfter, createdAt: instant)
        return try store().update { notebook in
            guard canRead(), canWrite() else { throw MCPToolError.researchWritingDisabled }
            if let existing = notebook.notes.first(where: { $0.id == id }) {
                let retry = ResearchNote(
                    id: id, title: note.title, content: note.content, sources: note.sources,
                    instrumentID: note.instrumentID, researchedAt: researchedAt,
                    reviewAfter: reviewAfter,
                    createdAt: existing.createdAt)
                guard retry == existing else { throw ResearchStoreError.duplicateID }
                return try json(existing)
            }
            notebook.notes.append(note)
            return try json(note)
        }
    }

    private func createProposal(_ args: [String: MCPJSONValue]) throws -> MCPJSONValue {
        try keys(
            args,
            required: [
                "requestID", "title", "action", "target", "amount", "rationale", "risks",
                "assumptions", "alternatives", "noteIDs", "financialDataReadAt", "validUntil",
            ])
        let instant = now()
        let id = try uuid(args, "requestID")
        guard let action = InvestmentAction(rawValue: try string(args, "action", maximum: 20)),
            let values = args["noteIDs"]?.arrayValue, (1...20).contains(values.count)
        else { throw MCPToolError.invalidArgument }
        let noteIDs = try values.map { value -> UUID in
            guard let raw = value.stringValue, let id = UUID(uuidString: raw) else {
                throw MCPToolError.invalidArgument
            }
            return id
        }
        guard Set(noteIDs).count == noteIDs.count else { throw MCPToolError.invalidArgument }
        let amount = try string(args, "amount", maximum: 30)
        guard amount.range(of: "^[0-9]+(\\.[0-9]{1,8})?$", options: .regularExpression) != nil,
            let decimal = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")),
            decimal > 0, decimal <= 1_000_000_000_000_000_000
        else { throw MCPToolError.invalidArgument }
        let readAt = try date(args, "financialDataReadAt")
        let validUntil = try date(args, "validUntil")
        guard readAt <= instant.addingTimeInterval(60), validUntil > instant, validUntil > readAt
        else {
            throw MCPToolError.invalidArgument
        }
        let proposal = InvestmentProposal(
            id: id, title: try string(args, "title", maximum: 200),
            action: action, target: try string(args, "target", maximum: 200), amount: amount,
            currencyCode: "VND",
            rationale: try string(args, "rationale", maximum: 5000),
            risks: try string(args, "risks", maximum: 5000),
            assumptions: try string(args, "assumptions", maximum: 5000),
            alternatives: try string(args, "alternatives", maximum: 5000),
            noteIDs: noteIDs, financialDataReadAt: readAt, validUntil: validUntil,
            createdAt: instant)
        return try store().update { notebook in
            guard canRead(), canWrite() else { throw MCPToolError.researchWritingDisabled }
            if let existing = notebook.proposals.first(where: { $0.id == id }) {
                let retry = InvestmentProposal(
                    id: id, title: proposal.title, action: action, target: proposal.target,
                    amount: amount, currencyCode: "VND", rationale: proposal.rationale,
                    risks: proposal.risks,
                    assumptions: proposal.assumptions, alternatives: proposal.alternatives,
                    noteIDs: noteIDs,
                    financialDataReadAt: readAt, validUntil: validUntil,
                    createdAt: existing.createdAt)
                guard retry == existing else { throw ResearchStoreError.duplicateID }
                return try json(existing)
            }
            guard
                noteIDs.allSatisfy({ id in
                    notebook.notes.contains { $0.id == id && $0.reviewAfter > instant }
                })
            else {
                throw ResearchStoreError.missingReference
            }
            notebook.proposals.append(proposal)
            return try json(proposal)
        }
    }

    private func keys(
        _ args: [String: MCPJSONValue], required: Set<String>, optional: Set<String> = []
    ) throws {
        guard required.isSubset(of: Set(args.keys)),
            Set(args.keys).isSubset(of: required.union(optional))
        else {
            throw MCPToolError.invalidArgument
        }
    }
    private func string(_ args: [String: MCPJSONValue], _ key: String, maximum: Int) throws
        -> String
    {
        guard let value = args[key]?.stringValue,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            value.count <= maximum
        else { throw MCPToolError.invalidArgument }
        return value
    }
    private func uuid(_ args: [String: MCPJSONValue], _ key: String) throws -> UUID {
        guard let id = UUID(uuidString: try string(args, key, maximum: 36)) else {
            throw MCPToolError.invalidArgument
        }
        return id
    }
    private func date(_ args: [String: MCPJSONValue], _ key: String) throws -> Date {
        let raw = try string(args, key, maximum: 50)
        guard
            let value = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(raw))
                ?? (try? Date.ISO8601FormatStyle().parse(raw))
        else { throw MCPToolError.invalidArgument }
        return value
    }
    private func integer(
        _ args: [String: MCPJSONValue], _ key: String, default fallback: Int,
        range: ClosedRange<Int>
    ) throws -> Int {
        guard let value = args[key] else { return fallback }
        guard case .int(let int) = value, range.contains(int) else {
            throw MCPToolError.invalidArgument
        }
        return int
    }
    private func dateValue(_ date: Date) -> MCPJSONValue { .string(date.formatted(.iso8601)) }
    private func json<T: Encodable>(_ value: T) throws -> MCPJSONValue {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try JSONDecoder().decode(MCPJSONValue.self, from: encoder.encode(value))
    }
}
