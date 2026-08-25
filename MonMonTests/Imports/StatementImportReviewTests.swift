import Foundation
import Testing

@testable import MonMon

@MainActor
@Suite("Statement import review state")
struct StatementImportReviewTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let importA = String(repeating: "a", count: 64)
    private let importB = String(repeating: "b", count: 64)

    @Test("Commit confirmation is available only for a ready review and contains counts")
    func commitConfirmationRequiresReadiness() throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let review = makeReview(fixture: fixture)

        #expect(review.commitConfirmation == nil)

        review.selectStatementAccount(fixture.firstAccountID)
        let confirmation = try #require(review.commitConfirmation)

        #expect(confirmation.summary.newTransactionCount == 2)
        #expect(confirmation.recordCount == 2)
        #expect(!confirmation.removesReviewedStatement)

        review.setResolution(.unresolved, forCandidateID: importA)

        #expect(review.commitConfirmation == nil)
    }

    @Test("An all-exact review requests confirmed cleanup without financial records")
    func allExactConfirmationRequestsCleanup() throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let exactSnapshot = StatementImportReviewSnapshot(
            accounts: fixture.snapshot.accounts,
            categories: fixture.snapshot.categories,
            transactions: [importA, importB].map {
                StatementImportTransactionSnapshot(
                    id: UUID(),
                    kind: .expense,
                    amount: 125_000,
                    occurredAt: occurredAt,
                    note: "Existing synthetic transaction",
                    accountID: fixture.firstAccountID,
                    currencyCode: VNDCurrency.code,
                    sourceImportID: $0
                )
            },
            transfers: [],
            defaults: fixture.snapshot.defaults
        )
        let review = StatementImportReview(
            preview: preview(stagedID: "all-exact"),
            snapshot: exactSnapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in .completed(StatementImportCommitReport()) },
            retryCleanup: { _ in true }
        )
        review.selectStatementAccount(fixture.firstAccountID)

        let confirmation = try #require(review.commitConfirmation)

        #expect(confirmation.recordCount == 0)
        #expect(confirmation.summary.alreadyImportedCount == 2)
        #expect(confirmation.removesReviewedStatement)
    }

    @Test("Skipped rows leave the active list and return when restored")
    func skippedRowsAreHiddenUntilRestored() throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let review = makeReview(fixture: fixture)
        review.selectStatementAccount(fixture.firstAccountID)
        let originalResolution = try #require(
            review.rows.first { $0.id == importA }?.resolution
        )

        review.setResolution(.skip, forCandidateID: importA)

        #expect(review.visibleRows.map(\.id) == [importB])
        #expect(review.rows.count == 2)
        #expect(review.summary.skippedCount == 1)

        review.setResolution(originalResolution, forCandidateID: importA)

        #expect(review.visibleRows.map(\.id) == [importA, importB])
        #expect(review.summary.skippedCount == 0)
    }

    @Test("Account changes preserve only choices valid in the rebuilt reconciliation")
    func accountChangesPreserveValidChoices() throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        fixture.mapping.remember(
            accountID: fixture.firstAccountID,
            bank: .tpBank,
            accountLastFour: "1234",
            accounts: fixture.snapshot.accounts,
            financialCommitSucceeded: true
        )
        let review = makeReview(fixture: fixture)

        #expect(review.statementAccountID == fixture.firstAccountID)
        review.setResolution(
            .transaction(categoryID: fixture.expenseCategoryID, note: "Owner note"),
            forCandidateID: importA
        )
        review.setResolution(
            .newTransfer(otherAccountID: fixture.secondAccountID, note: "Owner transfer"),
            forCandidateID: importB
        )

        review.selectStatementAccount(fixture.secondAccountID)

        #expect(
            review.rows.first { $0.id == importA }?.resolution
                == .transaction(categoryID: fixture.expenseCategoryID, note: "Owner note")
        )
        #expect(
            review.rows.first { $0.id == importB }?.resolution
                == .transaction(
                    categoryID: fixture.expenseCategoryID,
                    note: "Synthetic expense B"
                )
        )
    }

    @Test("Commit readiness requires complete input, a current account, and valid resolutions")
    func commitReadinessIsStrict() throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let review = makeReview(fixture: fixture)

        #expect(review.statementAccountID == nil)
        #expect(!review.isCommitReady)

        review.selectStatementAccount(fixture.firstAccountID)
        #expect(review.isCommitReady)

        review.setResolution(.unresolved, forCandidateID: importA)
        #expect(!review.isCommitReady)

        review.setResolution(
            .transaction(categoryID: fixture.incomeCategoryID, note: "Wrong direction"),
            forCandidateID: importA
        )
        #expect(!review.isCommitReady)

        review.setResolution(
            .transaction(categoryID: fixture.expenseCategoryID, note: "Valid"),
            forCandidateID: importA
        )
        #expect(review.isCommitReady)

        review.replace(
            preview: preview(stagedID: "incomplete", isComplete: false),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping
        )
        review.selectStatementAccount(fixture.firstAccountID)
        #expect(!review.isCommitReady)
    }

    @Test("Commit and cleanup retry expose distinct phases")
    func commitAndCleanupPhases() async throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let completion = StatementImportCommitReport(createdTransactionCount: 2)
        let review = StatementImportReview(
            preview: preview(stagedID: "cleanup"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in .cleanupNeeded(completion) },
            retryCleanup: { _ in true }
        )
        review.selectStatementAccount(fixture.firstAccountID)

        await review.commit()
        #expect(review.phase == .cleanupNeeded(completion))

        let savedRows = review.rows
        let savedAccountID = review.statementAccountID
        review.setResolution(.skip, forCandidateID: importA)
        review.selectStatementAccount(fixture.secondAccountID)

        #expect(review.rows == savedRows)
        #expect(review.statementAccountID == savedAccountID)
        #expect(review.phase == .cleanupNeeded(completion))

        await review.retryCleanup()
        #expect(review.phase == .saved(completion))
    }

    @Test("A second commit while saving is ignored")
    func doubleCommitIsIgnored() async throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let gate = CompletionGate()
        let report = StatementImportCommitReport(createdTransactionCount: 2)
        let review = StatementImportReview(
            preview: preview(stagedID: "double-submit"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in await gate.wait() },
            retryCleanup: { _ in true }
        )
        review.selectStatementAccount(fixture.firstAccountID)

        let firstCommit = Task { await review.commit() }
        await waitUntilRequested(by: gate)
        await review.commit()

        #expect(await gate.requestCount == 1)
        #expect(review.phase == .committing)

        await gate.resolve(.completed(report))
        await firstCommit.value

        #expect(review.phase == .saved(report))
    }

    @Test("A stale completion cannot overwrite a replacement statement")
    func staleCompletionIsDiscarded() async throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let gate = CompletionGate()
        let review = StatementImportReview(
            preview: preview(stagedID: "first"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in await gate.wait() },
            retryCleanup: { _ in true }
        )
        review.selectStatementAccount(fixture.firstAccountID)

        let task = Task { await review.commit() }
        await waitUntilRequested(by: gate)
        review.replace(
            preview: preview(stagedID: "second"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping
        )
        await gate.resolve(.completed(StatementImportCommitReport(createdTransactionCount: 1)))
        await task.value

        #expect(review.staged.id == "second")
        #expect(review.phase == .reviewing)
    }

    @Test("Commit errors map to content-free review failures")
    func commitErrorsAreContentFree() async throws {
        let fixture = try makeFixture()
        defer { fixture.removeDefaults() }
        let review = StatementImportReview(
            preview: preview(stagedID: "failure"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in throw StatementImportCommitError.staleReview },
            retryCleanup: { _ in false }
        )
        review.selectStatementAccount(fixture.firstAccountID)
        let choices = review.rows

        await review.commit()

        #expect(review.phase == .failed(.staleReview))
        #expect(review.rows == choices)
    }

    private func makeReview(fixture: Fixture) -> StatementImportReview {
        StatementImportReview(
            preview: preview(stagedID: "review"),
            snapshot: fixture.snapshot,
            accountMapping: fixture.mapping,
            complete: { _, _ in .completed(StatementImportCommitReport()) },
            retryCleanup: { _ in true }
        )
    }

    private func makeFixture() throws -> Fixture {
        let firstAccountID = UUID()
        let secondAccountID = UUID()
        let thirdAccountID = UUID()
        let expenseCategoryID = UUID()
        let incomeCategoryID = UUID()
        let suiteName = "StatementImportReviewTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return Fixture(
            defaults: defaults,
            suiteName: suiteName,
            mapping: StatementAccountMapping(defaults: defaults),
            snapshot: StatementImportReviewSnapshot(
                accounts: [firstAccountID, secondAccountID, thirdAccountID].map {
                    StatementImportAccountSnapshot(id: $0, currencyCode: VNDCurrency.code)
                },
                categories: [
                    StatementImportCategorySnapshot(
                        id: expenseCategoryID,
                        kind: .expense
                    ),
                    StatementImportCategorySnapshot(
                        id: incomeCategoryID,
                        kind: .income
                    ),
                ],
                transactions: [],
                transfers: [],
                defaults: StatementImportCategoryDefaults(
                    expenseCategoryID: expenseCategoryID,
                    incomeCategoryID: incomeCategoryID
                )
            ),
            firstAccountID: firstAccountID,
            secondAccountID: secondAccountID,
            expenseCategoryID: expenseCategoryID,
            incomeCategoryID: incomeCategoryID
        )
    }

    private func preview(stagedID: String, isComplete: Bool = true) -> StatementImportPreview {
        let candidates = [
            candidate(id: importA, note: "Synthetic expense A"),
            candidate(id: importB, note: "Synthetic expense B"),
        ]
        let totals = BankStatementTotals(debit: 250_000, credit: 0)
        return StatementImportPreview(
            staged: StagedBankStatement(
                id: stagedID,
                originalFilename: "synthetic.pdf",
                byteCount: 128,
                createdAt: occurredAt
            ),
            statement: ParsedBankStatement(
                bank: .tpBank,
                accountLastFour: "1234",
                currencyCode: VNDCurrency.code,
                period: occurredAt...occurredAt,
                candidates: candidates,
                declaredTotals: isComplete ? totals : nil,
                parsedTotals: totals,
                issues: []
            )
        )
    }

    private func candidate(id: String, note: String) -> BankTransactionCandidate {
        BankTransactionCandidate(
            id: id,
            occurredAt: occurredAt,
            kind: .expense,
            amount: 125_000,
            note: note,
            sourceReference: "SYNTHETIC-REFERENCE",
            sourcePage: 1
        )
    }

    private func waitUntilRequested(by gate: CompletionGate) async {
        for _ in 0..<100 {
            if await gate.isWaiting {
                return
            }
            await Task.yield()
        }
        Issue.record("Completion did not start")
    }

    private actor CompletionGate {
        private var continuation: CheckedContinuation<StatementImportCompletion, Never>?
        private(set) var requestCount = 0

        func wait() async -> StatementImportCompletion {
            requestCount += 1
            return await withCheckedContinuation { continuation = $0 }
        }

        var isWaiting: Bool {
            continuation != nil
        }

        func resolve(_ result: StatementImportCompletion) {
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    private struct Fixture {
        let defaults: UserDefaults
        let suiteName: String
        let mapping: StatementAccountMapping
        let snapshot: StatementImportReviewSnapshot
        let firstAccountID: UUID
        let secondAccountID: UUID
        let expenseCategoryID: UUID
        let incomeCategoryID: UUID

        func removeDefaults() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
}
