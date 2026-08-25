import Foundation
import Testing

@testable import MonMon

@Suite("Statement import inbox service")
struct StatementImportInboxServiceTests {
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
