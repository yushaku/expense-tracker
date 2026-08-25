import Foundation
import Testing

@testable import MonMon

@Suite("Statement import inbox state")
@MainActor
struct StatementImportInboxTests {
    @Test("Refresh distinguishes loaded empty, loaded pending, and failed states")
    func refreshPhases() async {
        let staged = Self.stagedStatement(id: "first")
        let service = StubInboxService(pending: [])
        let inbox = StatementImportInbox(service: service)

        await inbox.refresh()
        #expect(inbox.listPhase == .loaded([]))

        await service.setPending([staged])
        await inbox.refresh()
        #expect(inbox.listPhase == .loaded([staged]))

        await service.setListError(.fileSystem)
        await inbox.refresh()
        #expect(inbox.listPhase == .failed(.fileSystem))
    }

    @Test("Parser errors are safe and retry leaves the statement pending")
    func parserFailureDoesNotRemove() async {
        let staged = Self.stagedStatement(id: "unsupported")
        let service = StubInboxService(
            pending: [staged],
            previewError: BankStatementParserError.unsupportedFormat
        )
        let inbox = StatementImportInbox(service: service)

        await inbox.loadPreview(staged)

        #expect(
            inbox.previewPhase
                == .failed(staged: staged, failure: .unsupportedFormat)
        )
        #expect(await service.removedIDs().isEmpty)

        await inbox.loadPreview(staged)

        #expect(await service.removedIDs().isEmpty)
        #expect(await service.previewRequestCount() == 2)
    }

    @Test("An older parse cannot overwrite a newer selection")
    func stalePreviewIsDiscarded() async throws {
        let first = Self.stagedStatement(id: "first")
        let second = Self.stagedStatement(id: "second")
        let service = ControlledPreviewService(pending: [first, second])
        let inbox = StatementImportInbox(service: service)

        let firstTask = Task { await inbox.loadPreview(first) }
        await waitUntilRequested(first.id, by: service)

        let secondTask = Task { await inbox.loadPreview(second) }
        await waitUntilRequested(second.id, by: service)
        await service.resolve(second, with: Self.preview(for: second, reference: "SECOND"))
        await secondTask.value

        await service.resolve(first, with: Self.preview(for: first, reference: "FIRST"))
        await firstTask.value

        #expect(
            inbox.previewPhase
                == .loaded(Self.preview(for: second, reference: "SECOND"))
        )
    }

    @Test("Confirmed removal clears selection and refreshes pending statements")
    func removalRefreshesState() async {
        let first = Self.stagedStatement(id: "first")
        let second = Self.stagedStatement(id: "second")
        let service = StubInboxService(pending: [first, second])
        let inbox = StatementImportInbox(service: service)

        await inbox.loadPreview(first)
        let removed = await inbox.remove(first)

        #expect(removed)
        #expect(inbox.previewPhase == .idle)
        #expect(inbox.listPhase == .loaded([second]))
        #expect(await service.removedIDs() == [first.id])
    }

    private actor StubInboxService: StatementImportInboxServing {
        private var pending: [StagedBankStatement]
        private var listError: StatementIntakeError?
        private var previewError: BankStatementParserError?
        private var removed: [String] = []
        private var previewRequests = 0

        init(
            pending: [StagedBankStatement],
            previewError: BankStatementParserError? = nil
        ) {
            self.pending = pending
            self.previewError = previewError
        }

        func loadPendingStatements() async throws -> [StagedBankStatement] {
            if let listError {
                throw listError
            }
            return pending
        }

        func loadPreview(_ staged: StagedBankStatement) async throws -> StatementImportPreview {
            previewRequests += 1
            if let previewError {
                throw previewError
            }
            return StatementImportInboxTests.preview(for: staged, reference: staged.id)
        }

        func removeStatement(_ staged: StagedBankStatement) async throws {
            removed.append(staged.id)
            pending.removeAll { $0.id == staged.id }
        }

        func setPending(_ statements: [StagedBankStatement]) {
            pending = statements
            listError = nil
        }

        func setListError(_ error: StatementIntakeError) {
            listError = error
        }

        func removedIDs() -> [String] {
            removed
        }

        func previewRequestCount() -> Int {
            previewRequests
        }
    }

    private actor ControlledPreviewService: StatementImportInboxServing {
        private let pending: [StagedBankStatement]
        private var continuations: [String: CheckedContinuation<StatementImportPreview, Error>] =
            [:]

        init(pending: [StagedBankStatement]) {
            self.pending = pending
        }

        func loadPendingStatements() async throws -> [StagedBankStatement] {
            pending
        }

        func loadPreview(_ staged: StagedBankStatement) async throws -> StatementImportPreview {
            try await withCheckedThrowingContinuation { continuation in
                continuations[staged.id] = continuation
            }
        }

        func removeStatement(_ staged: StagedBankStatement) async throws {}

        func isWaiting(for id: String) -> Bool {
            continuations[id] != nil
        }

        func resolve(_ staged: StagedBankStatement, with preview: StatementImportPreview) {
            continuations.removeValue(forKey: staged.id)?.resume(returning: preview)
        }
    }

    private func waitUntilRequested(
        _ id: String,
        by service: ControlledPreviewService
    ) async {
        for _ in 0..<100 {
            if await service.isWaiting(for: id) {
                return
            }
            await Task.yield()
        }
        Issue.record("Preview request did not start")
    }

    nonisolated private static func stagedStatement(id: String) -> StagedBankStatement {
        StagedBankStatement(
            id: id,
            originalFilename: "\(id).pdf",
            byteCount: 128,
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    nonisolated private static func preview(
        for staged: StagedBankStatement,
        reference: String
    ) -> StatementImportPreview {
        let occurredAt = Date(timeIntervalSince1970: 1_000)
        let candidate = BankTransactionCandidate(
            id: reference,
            occurredAt: occurredAt,
            kind: .income,
            amount: 250_000,
            note: "Synthetic transfer",
            sourceReference: reference,
            sourcePage: 1
        )
        return StatementImportPreview(
            staged: staged,
            statement: ParsedBankStatement(
                bank: .tpBank,
                accountLastFour: "1234",
                currencyCode: "VND",
                period: occurredAt...occurredAt,
                candidates: [candidate],
                declaredTotals: BankStatementTotals(debit: 0, credit: 250_000),
                parsedTotals: BankStatementTotals(debit: 0, credit: 250_000),
                issues: []
            )
        )
    }
}
