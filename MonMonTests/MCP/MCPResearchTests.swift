import Darwin
import Foundation
import Testing

@testable import MonMon

@Suite("AI research notebook")
@MainActor
struct MCPResearchTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(
        "Writing needs separate permission and disabling financial access blocks all research tools"
    )
    func permissions() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        var reads = true
        var writes = false
        let service = MCPResearchService(
            store: fixture.store, canRead: { reads }, canWrite: { writes }, now: { now })
        #expect(throws: MCPToolError.researchWritingDisabled) {
            try service.call(.createNote, arguments: note())
        }
        #expect(try fixture.store.load().notes.isEmpty)
        writes = true
        _ = try service.call(.createNote, arguments: note())
        reads = false
        for tool in MCPResearchTool.allCases {
            #expect(throws: MCPToolError.disabled) { try service.call(tool, arguments: [:]) }
        }
    }

    @Test(
        "Identical retries are idempotent and conflicting content never overwrites research or decisions"
    )
    func retries() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let service = fixture.service(now: now)
        let input = note()
        let first = try service.call(.createNote, arguments: input)
        #expect(try service.call(.createNote, arguments: input) == first)
        var changed = input
        changed["content"] = .string("Changed")
        #expect(throws: ResearchStoreError.duplicateID) {
            try service.call(.createNote, arguments: changed)
        }
        let proposalInput = proposal(noteID: try #require(input["requestID"]?.stringValue))
        _ = try service.call(.createProposal, arguments: proposalInput)
        let rawID = try #require(proposalInput["requestID"]?.stringValue)
        let id = try #require(UUID(uuidString: rawID))
        try fixture.store.decide(
            proposalID: id, decision: .accepted, reason: "Fits my plan", now: now)
        _ = try service.call(.createProposal, arguments: proposalInput)
        let book = try fixture.store.load()
        #expect(book.notes.count == 1)
        #expect(book.proposals.count == 1)
        #expect(book.decisions.count == 1)
        #expect(book.decisions.first?.decision == .accepted)
    }

    @Test("Missing evidence, unsafe links, invalid money and forged decision fields are rejected")
    func validation() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let service = fixture.service(now: now)
        var badNote = note()
        badNote["sources"] = .array([
            .object([
                "title": .string("Unsafe"), "url": .string("file:///etc/passwd"),
                "accessedAt": date(now),
            ])
        ])
        #expect(throws: MCPToolError.invalidArgument) {
            try service.call(.createNote, arguments: badNote)
        }
        let input = note()
        _ = try service.call(.createNote, arguments: input)
        var inputProposal = proposal(noteID: try #require(input["requestID"]?.stringValue))
        inputProposal["amount"] = .string("100junk")
        #expect(throws: MCPToolError.invalidArgument) {
            try service.call(.createProposal, arguments: inputProposal)
        }
        inputProposal["amount"] = .string("100")
        inputProposal["status"] = .string("accepted")
        #expect(throws: MCPToolError.invalidArgument) {
            try service.call(.createProposal, arguments: inputProposal)
        }
        #expect(throws: ResearchStoreError.missingReference) {
            try service.call(.createProposal, arguments: proposal(noteID: UUID().uuidString))
        }
        #expect(try fixture.store.load().proposals.isEmpty)
    }

    @Test("Expired research blocks acceptance but the user can defer or reject with a reason")
    func decisions() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let service = fixture.service(now: now)
        let input = note()
        _ = try service.call(.createNote, arguments: input)
        let args = proposal(noteID: try #require(input["requestID"]?.stringValue))
        _ = try service.call(.createProposal, arguments: args)
        let rawID = try #require(args["requestID"]?.stringValue)
        let id = try #require(UUID(uuidString: rawID))
        #expect(throws: ResearchStoreError.expired) {
            try fixture.store.decide(
                proposalID: id, decision: .accepted, reason: "Yes",
                now: now.addingTimeInterval(100000))
        }
        try fixture.store.decide(
            proposalID: id, decision: .deferred, reason: "Need fresh rates",
            now: now.addingTimeInterval(100000))
        try fixture.store.decide(
            proposalID: id, decision: .rejected, reason: "Prefer cash",
            now: now.addingTimeInterval(100001))
        let book = try fixture.store.load()
        #expect(book.decisions.map(\.decision) == [.deferred, .rejected])
    }

    @Test("Corrupt documents and competing writers fail without replacing existing data")
    func persistence() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let service = fixture.service(now: now)
        _ = try service.call(.createNote, arguments: note())
        let file = fixture.store.directory.appending(path: "notebook.json")
        let before = try Data(contentsOf: file)
        let fd = open(fixture.store.directory.appending(path: "write.lock").path, O_RDWR)
        #expect(fd >= 0)
        defer { close(fd) }
        #expect(flock(fd, LOCK_EX | LOCK_NB) == 0)
        #expect(throws: ResearchStoreError.busy) {
            try service.call(.createNote, arguments: note())
        }
        flock(fd, LOCK_UN)
        #expect(try Data(contentsOf: file) == before)
        try Data("broken".utf8).write(to: file)
        #expect(throws: (any Error).self) { try service.call(.createNote, arguments: note()) }
        #expect(try Data(contentsOf: file) == Data("broken".utf8))
    }

    @Test("Revoking AI access clears draft-writing permission and retains local notes")
    func revocation() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        _ = try fixture.service(now: now).call(.createNote, arguments: note())
        let suite = "ResearchRevoke.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let consent = MCPConsentStore(defaults: defaults)
        consent.allow()
        defaults.set(true, forKey: MCPResearchService.writingAllowedKey)
        consent.revoke()
        #expect(!defaults.bool(forKey: MCPResearchService.writingAllowedKey))
        #expect(try fixture.store.load().notes.count == 1)
    }

    private func note() -> [String: MCPJSONValue] {
        [
            "requestID": .string(UUID().uuidString), "title": .string("Fund research"),
            "content": .string("Evidence and uncertainty"),
            "sources": .array([
                .object([
                    "title": .string("Provider"), "url": .string("https://example.com/fund"),
                    "accessedAt": date(now),
                ])
            ]),
            "researchedAt": date(now), "reviewAfter": date(now.addingTimeInterval(86400)),
        ]
    }
    private func proposal(noteID: String) -> [String: MCPJSONValue] {
        [
            "requestID": .string(UUID().uuidString), "title": .string("Consider saving"),
            "action": .string("saveCash"), "target": .string("Bank term deposit"),
            "amount": .string("1000000"), "rationale": .string("Liquidity"),
            "risks": .string("Inflation"),
            "assumptions": .string("Emergency fund exists"), "alternatives": .string("Hold cash"),
            "noteIDs": .array([.string(noteID)]),
            "financialDataReadAt": date(now), "validUntil": date(now.addingTimeInterval(86400)),
        ]
    }
    private func date(_ value: Date) -> MCPJSONValue { .string(value.formatted(.iso8601)) }

    private struct Fixture {
        let store: ResearchNotebookStore
        init() throws {
            store = ResearchNotebookStore(
                directory: FileManager.default.temporaryDirectory.appending(
                    path: "ResearchTests-\(UUID())"))
        }
        func cleanUp() { try? FileManager.default.removeItem(at: store.directory) }
        @MainActor func service(now: Date) -> MCPResearchService {
            MCPResearchService(store: store, canRead: { true }, canWrite: { true }, now: { now })
        }
    }
}
