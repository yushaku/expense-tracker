import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Statement import inbox service")
struct StatementImportInboxServiceTests {
    @Test("Configured App Group follows the build Info.plist")
    func appGroupIdentifierFollowsBuildConfiguration() {
        let expected = "group.com.sonlv.monmon.app"

        #expect(
            StatementInboxConfiguration.appGroupIdentifier(
                in: ["MonMonAppGroupIdentifier": expected]
            ) == expected
        )
    }

    @Test("Missing App Group configuration has no development fallback")
    func missingAppGroupIdentifierHasNoFallback() {
        #expect(StatementInboxConfiguration.appGroupIdentifier(in: [:]) == nil)
    }

    @Test("Pending statements preserve intake order and preview validated bytes")
    func listsAndPreviewsStatements() async throws {
        try await withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let firstData = fakePDF("first")
            let secondData = fakePDF("second")
            let firstURL = directory.appendingPathComponent("first.pdf")
            let secondURL = directory.appendingPathComponent("second.pdf")
            try firstData.write(to: firstURL)
            try secondData.write(to: secondURL)
            let firstStore = StatementIntakeStore(
                rootURL: rootURL,
                now: { Date(timeIntervalSince1970: 100) }
            )
            let secondStore = StatementIntakeStore(
                rootURL: rootURL,
                now: { Date(timeIntervalSince1970: 200) }
            )
            let first = try firstStore.stagePDF(
                at: firstURL,
                originalFilename: "first.pdf"
            )
            let second = try secondStore.stagePDF(
                at: secondURL,
                originalFilename: "second.pdf"
            )
            let parsed = parsedStatement(reference: "SYNTHETIC-001")
            let service = StatementImportInboxService(
                rootURL: rootURL,
                parser: ExpectedDataParser(expected: secondData, result: parsed)
            )

            #expect(try service.pendingStatements() == [first, second])

            let preview = try await service.preview(second)

            #expect(preview == StatementImportPreview(staged: second, statement: parsed))
        }
    }

    @Test("Removing one pending statement leaves its sibling intact")
    func removesOnlySelectedStatement() throws {
        try withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let store = StatementIntakeStore(rootURL: rootURL)
            let firstURL = directory.appendingPathComponent("first.pdf")
            let secondURL = directory.appendingPathComponent("second.pdf")
            try fakePDF("first").write(to: firstURL)
            try fakePDF("second").write(to: secondURL)
            let first = try store.stagePDF(at: firstURL, originalFilename: "first.pdf")
            let second = try store.stagePDF(at: secondURL, originalFilename: "second.pdf")
            let service = StatementImportInboxService(
                rootURL: rootURL,
                parser: ExpectedDataParser(
                    expected: Data(),
                    result: parsedStatement(reference: "UNUSED")
                )
            )

            try service.remove(first)
            try service.remove(first)

            #expect(try service.pendingStatements() == [second])
        }
    }

    @Test("Live composition reports an unavailable App Group")
    func unavailableAppGroupFailsClearly() {
        #expect(throws: StatementIntakeError.appGroupUnavailable) {
            try StatementImportInboxService.live(containerURL: { nil })
        }
    }

    @Test("Parser failures retain their typed error")
    func parserFailureIsPreserved() async throws {
        try await withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let sourceURL = directory.appendingPathComponent("source.pdf")
            try fakePDF("unsupported").write(to: sourceURL)
            let store = StatementIntakeStore(rootURL: rootURL)
            let staged = try store.stagePDF(at: sourceURL, originalFilename: "source.pdf")
            let service = StatementImportInboxService(
                rootURL: rootURL,
                parser: FailingParser(error: .unsupportedFormat)
            )

            await #expect(throws: BankStatementParserError.unsupportedFormat) {
                try await service.preview(staged)
            }
            #expect(try service.pendingStatements() == [staged])
        }
    }

    private struct ExpectedDataParser: BankStatementParsing {
        let expected: Data
        let result: ParsedBankStatement

        func parse(_ data: Data) throws -> ParsedBankStatement {
            guard data == expected else {
                throw BankStatementParserError.unsupportedFormat
            }
            return result
        }
    }

    private struct FailingParser: BankStatementParsing {
        let error: BankStatementParserError

        func parse(_ data: Data) throws -> ParsedBankStatement {
            throw error
        }
    }

    private func parsedStatement(reference: String) -> ParsedBankStatement {
        let occurredAt = Date(timeIntervalSince1970: 1_000)
        let candidate = BankTransactionCandidate(
            id: reference,
            occurredAt: occurredAt,
            kind: .expense,
            amount: 125_000,
            note: "Synthetic purchase",
            sourceReference: reference,
            sourcePage: 1
        )
        return ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "1234",
            currencyCode: "VND",
            period: occurredAt...occurredAt,
            candidates: [candidate],
            declaredTotals: BankStatementTotals(debit: 125_000, credit: 0),
            parsedTotals: BankStatementTotals(debit: 125_000, credit: 0),
            issues: []
        )
    }

    private func fakePDF(_ marker: String) -> Data {
        Data("%PDF-1.7\n% synthetic \(marker)\n%%EOF".utf8)
    }

    private func withTestDirectory(_ body: (URL) throws -> Void) throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func withTestDirectory(
        _ body: (URL) async throws -> Void
    ) async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await body(directory)
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonMonStatementImportInboxServiceTests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
@Suite("Statement import completion")
struct StatementImportCompletionTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let importID = String(repeating: "a", count: 64)

    @Test("Cleanup failure preserves saved records and supports cleanup-only retry")
    func cleanupFailureCanRetryWithoutFinancialWrite() throws {
        try withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let staged = try stagePDF(in: directory, rootURL: rootURL)
            let fixture = try makeFixture()
            defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
            let request = makeRequest(
                accountID: fixture.accountID,
                categoryID: fixture.categoryID
            )
            let failingInbox = StatementImportInboxService(
                rootURL: rootURL,
                removeStatement: { _ in throw StatementIntakeError.fileSystem }
            )

            let result = try failingInbox.completeImport(
                request,
                staged: staged,
                commitService: fixture.commitService,
                accountMapping: fixture.mapping
            )

            guard case let .cleanupNeeded(report) = result else {
                Issue.record("Expected retryable cleanup result")
                return
            }
            #expect(report.createdTransactionCount == 1)
            #expect(try fetchTransactions(from: fixture.container).count == 1)
            #expect(try failingInbox.pendingStatements() == [staged])
            #expect(
                fixture.mapping.resolve(
                    bank: .tpBank,
                    accountLastFour: "1234",
                    accounts: [
                        StatementImportAccountSnapshot(
                            id: fixture.accountID,
                            currencyCode: VNDCurrency.code
                        )
                    ]
                ) == fixture.accountID
            )

            let workingInbox = StatementImportInboxService(rootURL: rootURL)
            #expect(workingInbox.retryCleanup(staged))
            #expect(try workingInbox.pendingStatements().isEmpty)
            #expect(try fetchTransactions(from: fixture.container).count == 1)
        }
    }

    @Test("Financial save failure leaves mapping and staged PDF untouched")
    func saveFailureLeavesExternalStateUntouched() throws {
        try withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let staged = try stagePDF(in: directory, rootURL: rootURL)
            let fixture = try makeFixture(save: { _ in throw SyntheticSaveError() })
            defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
            let inbox = StatementImportInboxService(rootURL: rootURL)

            #expect(throws: StatementImportCommitError.storeFailure) {
                try inbox.completeImport(
                    makeRequest(
                        accountID: fixture.accountID,
                        categoryID: fixture.categoryID
                    ),
                    staged: staged,
                    commitService: fixture.commitService,
                    accountMapping: fixture.mapping
                )
            }

            #expect(try fetchTransactions(from: fixture.container).isEmpty)
            #expect(try inbox.pendingStatements() == [staged])
            #expect(
                fixture.mapping.resolve(
                    bank: .tpBank,
                    accountLastFour: "1234",
                    accounts: [
                        StatementImportAccountSnapshot(
                            id: fixture.accountID,
                            currencyCode: VNDCurrency.code
                        )
                    ]
                ) == nil
            )
        }
    }

    @Test("All-exact completion removes staging without a SwiftData save")
    func allExactCompletionSkipsFinancialSave() throws {
        try withTestDirectory { directory in
            let rootURL = directory.appendingPathComponent("shared")
            let staged = try stagePDF(in: directory, rootURL: rootURL)
            let fixture = try makeFixture(save: { _ in throw SyntheticSaveError() })
            defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
            try insertImportedTransaction(into: fixture)
            let inbox = StatementImportInboxService(rootURL: rootURL)
            let request = makeRequest(
                accountID: fixture.accountID,
                categoryID: fixture.categoryID,
                resolution: .alreadyImported
            )

            let result = try inbox.completeImport(
                request,
                staged: staged,
                commitService: fixture.commitService,
                accountMapping: fixture.mapping
            )

            guard case let .completed(report) = result else {
                Issue.record("Expected completed result")
                return
            }
            #expect(report.alreadyImportedCount == 1)
            #expect(try fetchTransactions(from: fixture.container).count == 1)
            #expect(try inbox.pendingStatements().isEmpty)
        }
    }

    private func makeFixture(
        save: @MainActor @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let accountID = UUID()
        let categoryID = UUID()
        context.insert(
            CashAccount(
                id: accountID,
                name: "Synthetic bank",
                kind: .bank,
                openingBalance: 1_000_000,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        )
        context.insert(
            TransactionCategory(
                id: categoryID,
                name: "Synthetic expense",
                kind: .expense,
                symbolName: CategoryPalette.defaultSymbolName,
                colorName: CategoryPalette.defaultColorName,
                createdAt: occurredAt
            )
        )
        try context.save()
        let suiteName = "StatementImportCompletionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return Fixture(
            container: container,
            commitService: StatementImportCommitService(container: container, save: save),
            defaults: defaults,
            mapping: StatementAccountMapping(defaults: defaults),
            suiteName: suiteName,
            accountID: accountID,
            categoryID: categoryID
        )
    }

    private func makeRequest(
        accountID: UUID,
        categoryID: UUID,
        resolution: ImportRowResolution? = nil
    ) -> StatementImportCommitRequest {
        let candidate = BankTransactionCandidate(
            id: importID,
            occurredAt: occurredAt,
            kind: .expense,
            amount: 125_000,
            note: "Synthetic purchase",
            sourceReference: "SYNTHETIC-REFERENCE",
            sourcePage: 1
        )
        let statement = ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "1234",
            currencyCode: VNDCurrency.code,
            period: occurredAt...occurredAt,
            candidates: [candidate],
            declaredTotals: BankStatementTotals(debit: 125_000, credit: 0),
            parsedTotals: BankStatementTotals(debit: 125_000, credit: 0),
            issues: []
        )
        return StatementImportCommitRequest(
            statement: statement,
            statementAccountID: accountID,
            rows: [
                ReconciledImportRow(
                    candidate: candidate,
                    disposition: .newTransaction,
                    resolution: resolution
                        ?? .transaction(categoryID: categoryID, note: "Synthetic purchase")
                )
            ]
        )
    }

    private func insertImportedTransaction(into fixture: Fixture) throws {
        let context = ModelContext(fixture.container)
        context.insert(
            MoneyTransaction(
                id: UUID(),
                kind: .expense,
                amount: 125_000,
                occurredAt: occurredAt,
                note: "Existing import",
                accountID: fixture.accountID,
                categoryID: fixture.categoryID,
                sourceRuleID: nil,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt,
                sourceImportID: importID
            )
        )
        try context.save()
    }

    private func stagePDF(in directory: URL, rootURL: URL) throws -> StagedBankStatement {
        let sourceURL = directory.appendingPathComponent("statement.pdf")
        try Data("%PDF-1.7\n% synthetic\n%%EOF".utf8).write(to: sourceURL)
        return try StatementIntakeStore(rootURL: rootURL).stagePDF(
            at: sourceURL,
            originalFilename: "statement.pdf"
        )
    }

    private func fetchTransactions(from container: ModelContainer) throws -> [MoneyTransaction] {
        try ModelContext(container).fetch(FetchDescriptor<MoneyTransaction>())
    }

    private func withTestDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonMonStatementImportCompletionTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private struct SyntheticSaveError: Error {}

    private struct Fixture {
        let container: ModelContainer
        let commitService: StatementImportCommitService
        let defaults: UserDefaults
        let mapping: StatementAccountMapping
        let suiteName: String
        let accountID: UUID
        let categoryID: UUID
    }
}
