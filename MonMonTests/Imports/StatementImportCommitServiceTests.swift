import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Statement import commit service")
struct StatementImportCommitServiceTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let importA = String(repeating: "a", count: 64)
    private let importB = String(repeating: "b", count: 64)

    @Test("Resolved rows create validated transactions with provenance")
    func createsTransactions() throws {
        let fixture = try makeFixture()
        let expense = candidate(id: importA, kind: .expense, amount: 125_000)
        let income = candidate(id: importB, kind: .income, amount: 500_000)
        let request = request(
            candidates: [expense, income],
            rows: [
                row(
                    expense,
                    resolution: .transaction(
                        categoryID: fixture.expenseCategoryID,
                        note: "  Owner expense note  "
                    )
                ),
                row(
                    income,
                    resolution: .transaction(
                        categoryID: fixture.incomeCategoryID,
                        note: "Owner income note"
                    )
                ),
            ],
            accountID: fixture.accountID
        )

        let report = try fixture.service.commit(request)
        let stored = try fetchTransactions(from: fixture.container)

        #expect(report.createdTransactionCount == 2)
        #expect(report.linkedCount == 0)
        #expect(stored.count == 2)
        #expect(
            stored.map(\.sourceImportID).compactMap { $0 }.sorted() == [importA, importB]
        )
        #expect(stored.first { $0.sourceImportID == importA }?.note == "Owner expense note")
        #expect(
            stored.first { $0.sourceImportID == importA }?.categoryID
                == fixture.expenseCategoryID
        )
        #expect(stored.first { $0.sourceImportID == importB }?.kind == .income)
    }

    @Test("An eligible link attaches provenance without creating a transaction")
    func linksExistingTransaction() throws {
        let fixture = try makeFixture()
        let targetID = UUID()
        try insert(
            transaction(
                id: targetID,
                accountID: fixture.accountID,
                categoryID: fixture.expenseCategoryID
            ),
            into: fixture.container
        )
        let source = candidate(id: importA)
        let request = request(
            candidates: [source],
            rows: [row(source, resolution: .linkTransaction(transactionID: targetID))],
            accountID: fixture.accountID
        )

        let report = try fixture.service.commit(request)
        let stored = try fetchTransactions(from: fixture.container)

        #expect(report.createdTransactionCount == 0)
        #expect(report.linkedCount == 1)
        #expect(stored.count == 1)
        #expect(stored.first?.id == targetID)
        #expect(stored.first?.sourceImportID == importA)
    }

    @Test("Exact and skipped rows make no financial write")
    func exactAndSkippedRowsDoNothing() throws {
        let fixture = try makeFixture()
        let exactID = UUID()
        try insert(
            transaction(
                id: exactID,
                accountID: fixture.accountID,
                categoryID: fixture.expenseCategoryID,
                sourceImportID: importA
            ),
            into: fixture.container
        )
        let exact = candidate(id: importA)
        let skipped = candidate(id: importB, amount: 300_000)
        let request = request(
            candidates: [exact, skipped],
            rows: [
                row(exact, resolution: .alreadyImported),
                row(skipped, resolution: .skip),
            ],
            accountID: fixture.accountID
        )

        let report = try fixture.service.commit(request)
        let stored = try fetchTransactions(from: fixture.container)

        #expect(report.alreadyImportedCount == 1)
        #expect(report.skippedCount == 1)
        #expect(stored.count == 1)
        #expect(stored.first?.id == exactID)
    }

    @Test("A stale link rolls back every row")
    func staleLinkPreventsPartialWrites() throws {
        let fixture = try makeFixture()
        let targetID = UUID()
        try insert(
            transaction(
                id: targetID,
                accountID: fixture.accountID,
                categoryID: fixture.expenseCategoryID,
                sourceImportID: importB
            ),
            into: fixture.container
        )
        let newCandidate = candidate(id: importA, amount: 900_000)
        let staleLink = candidate(id: String(repeating: "c", count: 64))
        let request = request(
            candidates: [newCandidate, staleLink],
            rows: [
                row(
                    newCandidate,
                    resolution: .transaction(
                        categoryID: fixture.expenseCategoryID,
                        note: "Would be inserted first"
                    )
                ),
                row(staleLink, resolution: .linkTransaction(transactionID: targetID)),
            ],
            accountID: fixture.accountID
        )

        #expect(throws: StatementImportCommitError.staleReview) {
            try fixture.service.commit(request)
        }
        let stored = try fetchTransactions(from: fixture.container)
        #expect(stored.count == 1)
        #expect(stored.first?.sourceImportID == importB)
    }

    @Test("Invalid, unresolved, or tampered requests write nothing")
    func invalidRequestsWriteNothing() throws {
        let fixture = try makeFixture()
        let valid = candidate(id: importA)
        let invalid = candidate(id: "invalid")
        let staleCategory = UUID()
        let requests = [
            request(
                candidates: [valid],
                rows: [row(valid, resolution: .unresolved)],
                accountID: fixture.accountID
            ),
            request(
                candidates: [invalid],
                rows: [
                    row(
                        invalid,
                        resolution: .transaction(
                            categoryID: fixture.expenseCategoryID,
                            note: "Invalid source"
                        )
                    )
                ],
                accountID: fixture.accountID
            ),
            request(
                candidates: [valid],
                rows: [
                    row(
                        valid,
                        resolution: .transaction(
                            categoryID: staleCategory,
                            note: "Stale category"
                        )
                    )
                ],
                accountID: fixture.accountID
            ),
            request(
                candidates: [valid],
                rows: [
                    row(
                        valid,
                        resolution: .transaction(
                            categoryID: fixture.incomeCategoryID,
                            note: "Wrong direction"
                        )
                    )
                ],
                accountID: fixture.accountID
            ),
            request(
                candidates: [valid],
                rows: [row(candidate(id: importB), resolution: .skip)],
                accountID: fixture.accountID
            ),
            request(
                candidates: [valid],
                rows: [row(valid, resolution: .skip)],
                accountID: fixture.accountID,
                isComplete: false
            ),
        ]

        for invalidRequest in requests {
            #expect(throws: StatementImportCommitError.invalidRequest) {
                try fixture.service.commit(invalidRequest)
            }
        }
        #expect(try fetchTransactions(from: fixture.container).isEmpty)
    }

    @Test("Repeating a successful request is idempotent")
    func repeatedRequestCreatesNoDuplicate() throws {
        let fixture = try makeFixture()
        let source = candidate(id: importA)
        let request = request(
            candidates: [source],
            rows: [
                row(
                    source,
                    resolution: .transaction(
                        categoryID: fixture.expenseCategoryID,
                        note: "Synthetic purchase"
                    )
                )
            ],
            accountID: fixture.accountID
        )

        #expect(try fixture.service.commit(request).createdTransactionCount == 1)
        let second = try fixture.service.commit(request)

        #expect(second.createdTransactionCount == 0)
        #expect(second.alreadyImportedCount == 1)
        #expect(try fetchTransactions(from: fixture.container).count == 1)
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let accountID = UUID()
        let expenseCategoryID = UUID()
        let incomeCategoryID = UUID()
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
        context.insert(category(id: expenseCategoryID, kind: .expense))
        context.insert(category(id: incomeCategoryID, kind: .income))
        try context.save()
        return Fixture(
            container: container,
            service: StatementImportCommitService(container: container),
            accountID: accountID,
            expenseCategoryID: expenseCategoryID,
            incomeCategoryID: incomeCategoryID
        )
    }

    private func request(
        candidates: [BankTransactionCandidate],
        rows: [ReconciledImportRow],
        accountID: UUID,
        isComplete: Bool = true
    ) -> StatementImportCommitRequest {
        let debit = candidates.filter { $0.kind == .expense }.reduce(Decimal.zero) {
            $0 + $1.amount
        }
        let credit = candidates.filter { $0.kind == .income }.reduce(Decimal.zero) {
            $0 + $1.amount
        }
        let totals = BankStatementTotals(debit: debit, credit: credit)
        let statement = ParsedBankStatement(
            bank: .tpBank,
            accountLastFour: "1234",
            currencyCode: VNDCurrency.code,
            period: occurredAt...occurredAt,
            candidates: candidates,
            declaredTotals: isComplete ? totals : nil,
            parsedTotals: totals,
            issues: []
        )
        return StatementImportCommitRequest(
            statement: statement,
            statementAccountID: accountID,
            rows: rows
        )
    }

    private func row(
        _ candidate: BankTransactionCandidate,
        resolution: ImportRowResolution
    ) -> ReconciledImportRow {
        ReconciledImportRow(
            candidate: candidate,
            disposition: .newTransaction,
            resolution: resolution
        )
    }

    private func candidate(
        id: String,
        kind: TransactionKind = .expense,
        amount: Decimal = 125_000
    ) -> BankTransactionCandidate {
        BankTransactionCandidate(
            id: id,
            occurredAt: occurredAt,
            kind: kind,
            amount: amount,
            note: "Synthetic source note",
            sourceReference: "SYNTHETIC-REFERENCE",
            sourcePage: 1
        )
    }

    private func category(id: UUID, kind: TransactionKind) -> TransactionCategory {
        TransactionCategory(
            id: id,
            name: "Synthetic category",
            kind: kind,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: occurredAt
        )
    }

    private func transaction(
        id: UUID,
        accountID: UUID,
        categoryID: UUID,
        sourceImportID: String? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: id,
            kind: .expense,
            amount: 125_000,
            occurredAt: occurredAt,
            note: "Synthetic existing note",
            accountID: accountID,
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt,
            sourceImportID: sourceImportID
        )
    }

    private func insert(_ transaction: MoneyTransaction, into container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(transaction)
        try context.save()
    }

    private func fetchTransactions(from container: ModelContainer) throws -> [MoneyTransaction] {
        try ModelContext(container).fetch(FetchDescriptor<MoneyTransaction>())
    }

    private struct Fixture {
        let container: ModelContainer
        let service: StatementImportCommitService
        let accountID: UUID
        let expenseCategoryID: UUID
        let incomeCategoryID: UUID
    }
}
