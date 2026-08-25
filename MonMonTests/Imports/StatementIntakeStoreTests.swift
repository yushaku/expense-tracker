import Foundation
import Testing

@testable import MonMon

@Suite("Statement share intake store")
struct StatementIntakeStoreTests {
    @Test("A valid PDF is published once and round-trips unchanged")
    func stagesAndReadsPDF() throws {
        try withTestDirectory { directory in
            let sourceData = fakePDF("first")
            let sourceURL = directory.appendingPathComponent("source.pdf")
            try sourceData.write(to: sourceURL)
            let store = StatementIntakeStore(
                rootURL: directory.appendingPathComponent("shared"),
                now: { Date(timeIntervalSince1970: 100) }
            )

            let staged = try store.stagePDF(at: sourceURL, originalFilename: "statement.pdf")

            #expect(staged.originalFilename == "statement.pdf")
            #expect(staged.byteCount == sourceData.count)
            #expect(staged.id.count == 64)
            #expect(try store.pendingStatements() == [staged])
            #expect(try store.data(for: staged) == sourceData)
        }
    }

    @Test("Identical bytes are idempotent across filename changes")
    func repeatedDeliveryDoesNotDuplicate() throws {
        try withTestDirectory { directory in
            let sourceData = fakePDF("same-content")
            let firstURL = directory.appendingPathComponent("first.pdf")
            let secondURL = directory.appendingPathComponent("second.pdf")
            try sourceData.write(to: firstURL)
            try sourceData.write(to: secondURL)
            let store = StatementIntakeStore(rootURL: directory.appendingPathComponent("shared"))

            let first = try store.stagePDF(at: firstURL, originalFilename: "first.pdf")
            let second = try store.stagePDF(at: secondURL, originalFilename: "renamed.pdf")

            #expect(second == first)
            #expect(try store.pendingStatements() == [first])
        }
    }

    @Test("Invalid and oversized files never become ready items")
    func rejectsUnsupportedFiles() throws {
        try withTestDirectory { directory in
            let invalidURL = directory.appendingPathComponent("invalid.pdf")
            let emptyURL = directory.appendingPathComponent("empty.pdf")
            let oversizedURL = directory.appendingPathComponent("oversized.pdf")
            try Data("not a pdf".utf8).write(to: invalidURL)
            try Data().write(to: emptyURL)
            try Data(count: StatementIntakeStore.maximumByteCount + 1).write(to: oversizedURL)
            let store = StatementIntakeStore(rootURL: directory.appendingPathComponent("shared"))

            #expect(throws: StatementIntakeError.unsupportedPDF) {
                try store.stagePDF(at: invalidURL, originalFilename: "invalid.pdf")
            }
            #expect(throws: StatementIntakeError.unsupportedPDF) {
                try store.stagePDF(at: emptyURL, originalFilename: "empty.pdf")
            }
            #expect(
                throws: StatementIntakeError.oversizedFile(
                    maximumBytes: StatementIntakeStore.maximumByteCount
                )
            ) {
                try store.stagePDF(at: oversizedURL, originalFilename: "oversized.pdf")
            }
            #expect(try store.pendingStatements().isEmpty)
        }
    }

    @Test("Source filenames are bounded display metadata, never storage paths")
    func sanitizesSourceFilename() throws {
        try withTestDirectory { directory in
            let sourceURL = directory.appendingPathComponent("source.pdf")
            let secondSourceURL = directory.appendingPathComponent("second-source.pdf")
            try fakePDF("safe-name").write(to: sourceURL)
            try fakePDF("bounded-name").write(to: secondSourceURL)
            let store = StatementIntakeStore(rootURL: directory.appendingPathComponent("shared"))
            let longName = String(repeating: "a", count: 200) + ".pdf"

            let traversing = try store.stagePDF(
                at: sourceURL,
                originalFilename: "../../private/account.pdf"
            )
            let bounded = try store.stagePDF(at: secondSourceURL, originalFilename: longName)

            #expect(traversing.originalFilename == "account.pdf")
            #expect(bounded.originalFilename.count <= 120)
            #expect(!traversing.originalFilename.contains("/"))
        }
    }

    @Test("Listing ignores partial and corrupt items, sorts ready items, and supports removal")
    func listsOnlyValidReadyItems() throws {
        try withTestDirectory { directory in
            let sharedURL = directory.appendingPathComponent("shared")
            let firstStore = StatementIntakeStore(
                rootURL: sharedURL,
                now: { Date(timeIntervalSince1970: 100) }
            )
            let secondStore = StatementIntakeStore(
                rootURL: sharedURL,
                now: { Date(timeIntervalSince1970: 200) }
            )
            let firstURL = directory.appendingPathComponent("first.pdf")
            let secondURL = directory.appendingPathComponent("second.pdf")
            try fakePDF("one").write(to: firstURL)
            try fakePDF("two").write(to: secondURL)
            let first = try firstStore.stagePDF(at: firstURL, originalFilename: "first.pdf")
            let second = try secondStore.stagePDF(at: secondURL, originalFilename: "second.pdf")
            let inboxURL = sharedURL.appendingPathComponent("BankStatementInbox")
            let readyURL = inboxURL.appendingPathComponent("ready")
            try FileManager.default.createDirectory(
                at: inboxURL.appendingPathComponent("partial-interrupted"),
                withIntermediateDirectories: true
            )
            let corruptURL = readyURL.appendingPathComponent(String(repeating: "f", count: 64))
            try FileManager.default.createDirectory(
                at: corruptURL,
                withIntermediateDirectories: true
            )
            try Data("invalid json".utf8).write(
                to: corruptURL.appendingPathComponent("manifest.json")
            )

            #expect(try firstStore.pendingStatements() == [first, second])

            try firstStore.remove(first)

            #expect(try firstStore.pendingStatements() == [second])
            #expect(throws: StatementIntakeError.malformedStagedItem) {
                try firstStore.data(for: first)
            }
        }
    }

    private func fakePDF(_ marker: String) -> Data {
        Data("%PDF-1.7\n% synthetic \(marker)\n%%EOF".utf8)
    }

    private func withTestDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonMonStatementIntakeTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }
}
