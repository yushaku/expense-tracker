import Foundation
import Testing

@testable import MonMon

@Suite("TPBank PDF statement recognition")
struct TPBankPDFStatementParserTests {
    private let parser = TPBankPDFStatementParser()

    @Test("Bilingual TPBank headings and columns expose only safe metadata")
    func recognizesTPBankMetadata() throws {
        let metadata = try parser.metadata(from: TPBankPDFTestFixture.statement())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))

        #expect(metadata.bank == .tpBank)
        #expect(metadata.accountLastFour == "9012")
        #expect(metadata.currencyCode == "VND")
        #expect(
            calendar.dateComponents([.year, .month, .day], from: metadata.period.lowerBound)
                == DateComponents(year: 2026, month: 5, day: 1)
        )
        #expect(
            calendar.dateComponents([.year, .month, .day], from: metadata.period.upperBound)
                == DateComponents(year: 2026, month: 7, day: 31)
        )
    }

    @Test("Empty bytes and another bank are unsupported")
    func unsupportedDocumentsFailClearly() {
        #expect(throws: BankStatementParserError.unsupportedFormat) {
            try parser.metadata(from: Data())
        }
        #expect(throws: BankStatementParserError.unsupportedFormat) {
            try parser.metadata(from: TPBankPDFTestFixture.unrelatedStatement())
        }
    }

    @Test("A page without text is rejected instead of invoking OCR")
    func textlessDocumentFailsClearly() {
        #expect(throws: BankStatementParserError.missingTextLayer) {
            try parser.metadata(from: TPBankPDFTestFixture.imageOnlyStatement())
        }
    }

    @Test("Encrypted statements are rejected even when fixture credentials are known")
    func encryptedDocumentFailsClearly() {
        #expect(throws: BankStatementParserError.encryptedDocument) {
            try parser.metadata(
                from: TPBankPDFTestFixture.statement(password: "fixture-password")
            )
        }
    }

    @Test("A recognized statement without required columns has an unknown layout")
    func missingColumnsFailClearly() {
        #expect(throws: BankStatementParserError.unrecognizedLayout) {
            try parser.metadata(from: TPBankPDFTestFixture.statement(includeColumns: false))
        }
    }

    @Test("A recognized layout without period and currency has invalid metadata")
    func missingMetadataFailsClearly() {
        #expect(throws: BankStatementParserError.invalidStatementMetadata) {
            try parser.metadata(from: TPBankPDFTestFixture.statement(includeMetadata: false))
        }
    }

    @Test("Debit and credit rows keep visual order and positive exact amounts")
    func parsesTransactionRowsByColumn() throws {
        let data = TPBankPDFTestFixture.statement(rows: [
            .init(
                date: "02/05/2026 08:15:00",
                reference: "FAKE-REF-001",
                noteLines: ["Synthetic grocery payment"],
                debit: "125,000",
                credit: nil
            ),
            .init(
                date: "03/05/2026 09:30:00",
                reference: "FAKE-REF-002",
                noteLines: ["Synthetic salary"],
                debit: nil,
                credit: "5.000.000"
            ),
        ])

        let statement = try parser.parse(data)

        #expect(statement.candidates.map(\.sourceReference) == ["FAKE-REF-001", "FAKE-REF-002"])
        #expect(statement.candidates.map(\.kind) == [.expense, .income])
        #expect(statement.candidates.map(\.amount) == [125_000, 5_000_000])
        #expect(statement.candidates.map(\.sourcePage) == [1, 1])
        #expect(statement.parsedTotals == BankStatementTotals(debit: 125_000, credit: 5_000_000))
        #expect(statement.issues.isEmpty)
    }

    @Test("Wrapped explanation lines stay attached to their transaction")
    func preservesWrappedNotes() throws {
        let data = TPBankPDFTestFixture.statement(rows: [
            .init(
                date: "04/05/2026 10:45:00",
                reference: "FAKE-REF-003",
                noteLines: ["Synthetic online purchase", "Order FAKE-42"],
                debit: "250,500",
                credit: nil
            )
        ])

        let statement = try parser.parse(data)

        let candidate = try #require(statement.candidates.first)
        #expect(candidate.note == "Synthetic online purchase Order FAKE-42")
        #expect(candidate.kind == .expense)
        #expect(candidate.amount == 250_500)
    }

    @Test("Three pages preserve order, skip repeated structure, and reconcile totals")
    func parsesAndReconcilesMultiplePages() throws {
        let pages: [[TPBankPDFTestFixture.Row]] = [
            [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-P1",
                    noteLines: ["Page one expense"],
                    debit: "100,000",
                    credit: nil
                )
            ],
            [
                .init(
                    date: "03/05/2026 09:30:00",
                    reference: "FAKE-P2",
                    noteLines: ["Page two income"],
                    debit: nil,
                    credit: "5,000,000"
                )
            ],
            [
                .init(
                    date: "04/05/2026 10:45:00",
                    reference: "FAKE-P3",
                    noteLines: ["Page three expense"],
                    debit: "275,500",
                    credit: nil
                )
            ],
        ]
        let data = TPBankPDFTestFixture.statement(
            pages: pages,
            declaredTotals: .init(debit: "375,500", credit: "5,000,000")
        )

        let first = try parser.parse(data)
        let second = try parser.parse(data)

        #expect(first.candidates.map(\.sourceReference) == ["FAKE-P1", "FAKE-P2", "FAKE-P3"])
        #expect(first.candidates.map(\.sourcePage) == [1, 2, 3])
        #expect(first.candidates.map(\.id) == second.candidates.map(\.id))
        #expect(first.declaredTotals == BankStatementTotals(debit: 375_500, credit: 5_000_000))
        #expect(first.issues.isEmpty)
        #expect(first.isComplete)
    }

    @Test("A footer-only final page does not invalidate transaction pages")
    func skipsFooterOnlyLastPage() throws {
        let data = TPBankPDFTestFixture.statementWithFooterOnlyLastPage(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-FTR-01",
                    noteLines: ["Synthetic expense"],
                    debit: "125,000",
                    credit: nil
                )
            ],
            declaredTotals: .init(debit: "125,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.candidates.map(\.sourceReference) == ["FAKE-FTR-01"])
        #expect(statement.declaredTotals == BankStatementTotals(debit: 125_000, credit: 0))
        #expect(statement.isComplete)
    }

    @Test("Running balances are not mistaken for credit amounts")
    func ignoresBalanceColumn() throws {
        let data = TPBankPDFTestFixture.statement(
            includeBalance: true,
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-BAL-01",
                    noteLines: ["Synthetic expense"],
                    debit: "125,000",
                    credit: nil,
                    balance: "4,875,000"
                )
            ],
            declaredTotals: .init(debit: "125,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.candidates.map(\.sourceReference) == ["FAKE-BAL-01"])
        #expect(statement.candidates.map(\.amount) == [125_000])
        #expect(statement.candidates.map(\.kind) == [.expense])
        #expect(statement.isComplete)
    }

    @Test("A transaction with a date but no time uses the start of that day")
    func parsesDateOnlyTransaction() throws {
        let data = TPBankPDFTestFixture.statement(
            rows: [
                .init(
                    date: "02/05/2026",
                    reference: "FAKE-DATE-01",
                    noteLines: ["Synthetic income"],
                    debit: nil,
                    credit: "125,000"
                )
            ],
            declaredTotals: .init(debit: "0", credit: "125,000")
        )

        let statement = try parser.parse(data)
        let candidate = try #require(statement.candidates.first)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))

        #expect(
            calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: candidate.occurredAt
            ) == DateComponents(year: 2026, month: 5, day: 2, hour: 0, minute: 0, second: 0)
        )
        #expect(candidate.kind == .income)
        #expect(statement.isComplete)
    }

    @Test("A row with both amount columns is reported and makes totals incomplete")
    func reportsAmbiguousAmountRows() throws {
        let data = TPBankPDFTestFixture.statement(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-VALID",
                    noteLines: ["Valid income"],
                    debit: nil,
                    credit: "1,000"
                ),
                .init(
                    date: "03/05/2026 09:30:00",
                    reference: "FAKE-AMBIGUOUS",
                    noteLines: ["Ambiguous row"],
                    debit: "2,000",
                    credit: "2,000"
                ),
            ],
            declaredTotals: .init(debit: "2,000", credit: "3,000")
        )

        let statement = try parser.parse(data)

        #expect(statement.issues.contains(.ambiguousAmount(page: 1, row: 2)))
        #expect(statement.issues.contains(.totalsMismatch))
        #expect(!statement.isComplete)
    }

    @Test("A row with neither amount column is reported instead of disappearing")
    func reportsEmptyAmountRows() throws {
        let data = TPBankPDFTestFixture.statement(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-VALID",
                    noteLines: ["Valid expense"],
                    debit: "1,000",
                    credit: nil
                ),
                .init(
                    date: "03/05/2026 09:30:00",
                    reference: "FAKE-EMPTY",
                    noteLines: ["Missing amount"],
                    debit: nil,
                    credit: nil
                ),
            ],
            declaredTotals: .init(debit: "1,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.issues.contains(.ambiguousAmount(page: 1, row: 2)))
        #expect(!statement.isComplete)
    }

    @Test("Declared totals that exceed parsed rows create a totals mismatch")
    func reportsTotalsMismatch() throws {
        let data = TPBankPDFTestFixture.statement(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-ONLY-ROW",
                    noteLines: ["Only parsed row"],
                    debit: "1,000",
                    credit: nil
                )
            ],
            declaredTotals: .init(debit: "2,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.issues.contains(.totalsMismatch))
        #expect(!statement.isComplete)
    }

    @Test("A note containing Total does not shadow the footer")
    func findsTheLowestTotalsLabel() throws {
        let data = TPBankPDFTestFixture.statement(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-TOTAL-NOTE",
                    noteLines: ["Total card purchase"],
                    debit: "1,000",
                    credit: nil
                )
            ],
            declaredTotals: .init(debit: "1,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.declaredTotals == BankStatementTotals(debit: 1_000, credit: 0))
        #expect(statement.isComplete)
    }

    @Test("Extraction-confirmation headings and separated account values are supported")
    func parsesExtractionConfirmationVariant() throws {
        let data = TPBankPDFTestFixture.extractionConfirmationStatement(
            rows: [
                .init(
                    date: "02/05/2026 08:15:00",
                    reference: "FAKE-CFM-001",
                    noteLines: ["Synthetic confirmation row"],
                    debit: "1,000",
                    credit: nil
                )
            ],
            declaredTotals: .init(debit: "1,000", credit: "0")
        )

        let statement = try parser.parse(data)

        #expect(statement.accountLastFour == "3333")
        #expect(statement.candidates.map(\.sourceReference) == ["FAKE-CFM-001"])
        #expect(statement.isComplete)
    }
}
