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
        let storedIncome = try #require(stored.first { $0.sourceImportID == importB })
        #expect(
            try IncomeAllocationLifecycle.snapshot(in: storedIncome)?.allocatedAmount == 500_000
        )
        #expect(stored.first { $0.sourceImportID == importA }?.incomeAllocationSnapshot == nil)
    }

    @Test("Link actions are rejected without modifying existing transactions")
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

        #expect(throws: StatementImportCommitError.invalidRequest) {
            try fixture.service.commit(request)
        }
        let stored = try fetchTransactions(from: fixture.container)
        #expect(stored.count == 1)
        #expect(stored.first?.id == targetID)
        #expect(stored.first?.sourceImportID == nil)
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

        #expect(throws: StatementImportCommitError.invalidRequest) {
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

    @Test("Transfer creation is rejected without any financial writes")
    func createsDirectionCorrectTransfers() throws {
        let fixture = try makeFixture()
        let outgoing = candidate(id: importA, kind: .expense, amount: 9_000_000)
        let incoming = candidate(id: importB, kind: .income, amount: 2_000_000)
        let request = request(
            candidates: [outgoing, incoming],
            rows: [
                row(
                    outgoing,
                    resolution: .newTransfer(
                        otherAccountID: fixture.otherAccountID,
                        note: "  Historical outgoing  "
                    )
                ),
                row(
                    incoming,
                    resolution: .newTransfer(
                        otherAccountID: fixture.otherAccountID,
                        note: "Historical incoming"
                    )
                ),
            ],
            accountID: fixture.accountID
        )

        #expect(throws: StatementImportCommitError.invalidRequest) {
            try fixture.service.commit(request)
        }
        #expect(try fetchTransfers(from: fixture.container).isEmpty)
        #expect(try fetchTransactions(from: fixture.container).isEmpty)
    }

    @Test("Transfer links are rejected without changing provenance")
    func linksDirectionCorrectTransferSides() throws {
        let fixture = try makeFixture()
        let outgoingID = UUID()
        let incomingID = UUID()
        try insert(
            transfer(
                id: outgoingID,
                sourceAccountID: fixture.accountID,
                destinationAccountID: fixture.otherAccountID,
                destinationAccountImportID: String(repeating: "c", count: 64)
            ),
            into: fixture.container
        )
        try insert(
            transfer(
                id: incomingID,
                sourceAccountID: fixture.otherAccountID,
                destinationAccountID: fixture.accountID,
                sourceAccountImportID: String(repeating: "d", count: 64)
            ),
            into: fixture.container
        )
        let outgoing = candidate(id: importA, kind: .expense)
        let incoming = candidate(id: importB, kind: .income)
        let request = request(
            candidates: [outgoing, incoming],
            rows: [
                row(outgoing, resolution: .linkTransfer(transferID: outgoingID)),
                row(incoming, resolution: .linkTransfer(transferID: incomingID)),
            ],
            accountID: fixture.accountID
        )

        #expect(throws: StatementImportCommitError.invalidRequest) {
            try fixture.service.commit(request)
        }
        let transfers = try fetchTransfers(from: fixture.container)
        #expect(transfers.count == 2)
        #expect(transfers.first { $0.id == outgoingID }?.sourceAccountImportID == nil)
        #expect(transfers.first { $0.id == incomingID }?.destinationAccountImportID == nil)
        #expect(try fetchTransactions(from: fixture.container).isEmpty)
    }

    @Test("Invalid transfer endpoints roll back every row")
    func invalidTransferEndpointsWriteNothing() throws {
        let fixture = try makeFixture()
        let ordinary = candidate(id: importA)
        let invalidTransfer = candidate(id: importB, kind: .income)
        let request = request(
            candidates: [ordinary, invalidTransfer],
            rows: [
                row(
                    ordinary,
                    resolution: .transaction(
                        categoryID: fixture.expenseCategoryID,
                        note: "Must roll back"
                    )
                ),
                row(
                    invalidTransfer,
                    resolution: .newTransfer(
                        otherAccountID: fixture.accountID,
                        note: "Same endpoint"
                    )
                ),
            ],
            accountID: fixture.accountID
        )

        #expect(throws: StatementImportCommitError.invalidRequest) {
            try fixture.service.commit(request)
        }
        #expect(try fetchTransactions(from: fixture.container).isEmpty)
        #expect(try fetchTransfers(from: fixture.container).isEmpty)
    }

    @Test("Selected report rows import without account balance or aggregate total checks")
    func importsHistoricalExpenseWithoutBalanceChecks() throws {
        let fixture = try makeFixture()
        let source = candidate(id: importA, amount: 9_000_000)
        let base = request(
            candidates: [source],
            rows: [
                row(
                    source,
                    resolution: .transaction(
                        categoryID: fixture.expenseCategoryID, note: source.note))
            ],
            accountID: fixture.accountID
        )
        for totals in [nil, BankStatementTotals(debit: 1, credit: 1)] as [BankStatementTotals?] {
            let statement = ParsedBankStatement(
                bank: base.statement.bank, accountLastFour: base.statement.accountLastFour,
                currencyCode: base.statement.currencyCode, period: base.statement.period,
                candidates: base.statement.candidates, declaredTotals: totals,
                parsedTotals: base.statement.parsedTotals, issues: []
            )
            _ = try fixture.service.commit(
                StatementImportCommitRequest(
                    statement: statement, statementAccountID: fixture.accountID, rows: base.rows
                ))
        }
        let stored = try fetchTransactions(from: fixture.container)
        #expect(stored.count == 1)
        #expect(stored.first?.amount == 9_000_000)
        #expect(stored.first?.accountID == fixture.accountID)
        #expect(stored.first?.kind == .expense)
        #expect(try fetchTransfers(from: fixture.container).isEmpty)
    }

    @Test("Unchecked rows write nothing even if their category is unresolved")
    func importsOnlyCheckedRows() throws {
        let fixture = try makeFixture()
        let selected = candidate(id: importA)
        let omitted = candidate(id: importB)
        var unchecked = row(omitted, resolution: .unresolved)
        unchecked.isSelected = false
        let report = try fixture.service.commit(
            request(
                candidates: [selected, omitted],
                rows: [
                    row(
                        selected,
                        resolution: .transaction(
                            categoryID: fixture.expenseCategoryID, note: "Selected")), unchecked,
                ],
                accountID: fixture.accountID
            ))
        #expect(report.createdTransactionCount == 1)
        #expect(report.skippedCount == 1)
        #expect(try fetchTransactions(from: fixture.container).map(\.sourceImportID) == [importA])
        #expect(try fetchTransfers(from: fixture.container).isEmpty)
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
                kind: .normal,
                openingBalance: 1_000_000,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        )
        let otherAccountID = UUID()
        context.insert(
            CashAccount(
                id: otherAccountID,
                name: "Synthetic wallet",
                kind: .normal,
                openingBalance: 0,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        )
        context.insert(category(id: expenseCategoryID, kind: .expense))
        context.insert(category(id: incomeCategoryID, kind: .income))
        context.insert(
            BudgetJar(
                id: UUID(),
                name: "Savings",
                allocationPercent: 100,
                role: .savings,
                symbolName: "building.columns.fill",
                colorName: "yellow",
                createdAt: occurredAt
            )
        )
        try context.save()
        return Fixture(
            container: container,
            service: StatementImportCommitService(container: container),
            accountID: accountID,
            otherAccountID: otherAccountID,
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
            issues: isComplete ? [] : [.invalidRow(page: 1, row: 1)]
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

    private func transfer(
        id: UUID,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        sourceAccountImportID: String? = nil,
        destinationAccountImportID: String? = nil
    ) -> AccountTransfer {
        AccountTransfer(
            id: id,
            amount: 125_000,
            occurredAt: occurredAt,
            note: "Synthetic existing transfer",
            sourceAccountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt,
            sourceAccountImportID: sourceAccountImportID,
            destinationAccountImportID: destinationAccountImportID
        )
    }

    private func insert(_ transfer: AccountTransfer, into container: ModelContainer) throws {
        let context = ModelContext(container)
        context.insert(transfer)
        try context.save()
    }

    private func fetchTransactions(from container: ModelContainer) throws -> [MoneyTransaction] {
        try ModelContext(container).fetch(FetchDescriptor<MoneyTransaction>())
    }

    private func fetchTransfers(from container: ModelContainer) throws -> [AccountTransfer] {
        try ModelContext(container).fetch(FetchDescriptor<AccountTransfer>())
    }

    private struct Fixture {
        let container: ModelContainer
        let service: StatementImportCommitService
        let accountID: UUID
        let otherAccountID: UUID
        let expenseCategoryID: UUID
        let incomeCategoryID: UUID
    }
}
