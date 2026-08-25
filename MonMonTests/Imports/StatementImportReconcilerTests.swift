import Foundation
import Testing

@testable import MonMon

@Suite("Statement import reconciler")
struct StatementImportReconcilerTests {
    private let accountID = UUID()
    private let otherAccountID = UUID()
    private let expenseCategoryID = UUID()
    private let incomeCategoryID = UUID()
    private let candidateTime = Date(timeIntervalSince1970: 1_700_000_000)
    private let importA = String(repeating: "a", count: 64)
    private let importB = String(repeating: "b", count: 64)

    @Test("Exact transaction provenance wins and needs no action")
    func exactTransactionIsAlreadyImported() throws {
        let transactionID = UUID()
        let result = reconcile(
            candidates: [candidate(id: importA)],
            transactions: [
                transaction(
                    id: transactionID,
                    sourceImportID: importA,
                    note: "Different owner note"
                )
            ]
        )

        let row = try #require(result.rows.first)
        #expect(row.disposition == .exactImportedTransaction(transactionID: transactionID))
        #expect(row.resolution == .alreadyImported)
        #expect(result.summary.alreadyImportedCount == 1)
        #expect(result.summary.unresolvedCount == 0)
    }

    @Test("Exact transfer provenance uses the direction-correct account side")
    func exactTransferUsesCorrectSide() throws {
        let outgoingID = UUID()
        let incomingID = UUID()
        let outgoing = transfer(
            id: outgoingID,
            sourceAccountImportID: importA
        )
        let incoming = transfer(
            id: incomingID,
            sourceAccountID: otherAccountID,
            destinationAccountID: accountID,
            destinationAccountImportID: importB
        )

        let result = reconcile(
            candidates: [
                candidate(id: importA, kind: .expense),
                candidate(id: importB, kind: .income),
            ],
            transfers: [incoming, outgoing]
        )

        #expect(
            result.rows.map(\.disposition) == [
                .exactTransfer(transferID: outgoingID),
                .exactTransfer(transferID: incomingID),
            ]
        )
        #expect(result.rows.allSatisfy { $0.resolution == .alreadyImported })
    }

    @Test("Possible transaction requires every financial field but ignores note")
    func possibleTransactionUsesConservativeFields() throws {
        let matchingID = UUID()
        let result = reconcile(
            candidates: [candidate(id: importA, note: "Source note")],
            transactions: [
                transaction(id: matchingID, note: "Unrelated note"),
                transaction(id: UUID(), accountID: otherAccountID),
                transaction(id: UUID(), kind: .income),
                transaction(id: UUID(), amount: 125_001),
                transaction(id: UUID(), currencyCode: "USD"),
                transaction(id: UUID(), occurredAt: candidateTime.addingTimeInterval(86_400)),
                transaction(id: UUID(), sourceImportID: importB),
            ]
        )

        let row = try #require(result.rows.first)
        #expect(
            row.disposition
                == .possibleMatches(transactionIDs: [matchingID], transferIDs: [])
        )
        #expect(row.resolution == .unresolved)
    }

    @Test("Local-day matching uses Asia Ho Chi Minh rather than the UTC day")
    func localDayUsesVietnamCalendar() throws {
        let calendar = try vietnamCalendar()
        let afterMidnight = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 0, minute: 30))
        )
        let beforeMidnight = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 23))
        )
        let matchingID = UUID()

        let result = reconcile(
            candidates: [candidate(id: importA, occurredAt: afterMidnight)],
            transactions: [transaction(id: matchingID, occurredAt: beforeMidnight)],
            calendar: calendar
        )

        #expect(
            result.rows.first?.disposition
                == .possibleMatches(transactionIDs: [matchingID], transferIDs: [])
        )
    }

    @Test("Possible transfers require correct side and empty corresponding provenance")
    func possibleTransferUsesDirectionAndEmptySide() throws {
        let outgoingID = UUID()
        let incomingID = UUID()
        let result = reconcile(
            candidates: [
                candidate(id: importA, kind: .expense),
                candidate(id: importB, kind: .income),
            ],
            transfers: [
                transfer(id: outgoingID),
                transfer(
                    id: incomingID,
                    sourceAccountID: otherAccountID,
                    destinationAccountID: accountID
                ),
                transfer(id: UUID(), sourceAccountImportID: importB),
                transfer(
                    id: UUID(),
                    sourceAccountID: otherAccountID,
                    destinationAccountID: accountID,
                    destinationAccountImportID: importA
                ),
            ]
        )

        #expect(
            result.rows.map(\.disposition) == [
                .possibleMatches(transactionIDs: [], transferIDs: [outgoingID]),
                .possibleMatches(transactionIDs: [], transferIDs: [incomingID]),
            ]
        )
        #expect(result.rows.allSatisfy { $0.resolution == .unresolved })
    }

    @Test("Multiple possible matches stay unresolved and sort ids deterministically")
    func ambiguousMatchesStayUnresolved() throws {
        let lowID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let highID = try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000002"))
        let result = reconcile(
            candidates: [candidate(id: importA)],
            transactions: [transaction(id: highID), transaction(id: lowID)]
        )

        let row = try #require(result.rows.first)
        #expect(
            row.disposition
                == .possibleMatches(transactionIDs: [lowID, highID], transferIDs: [])
        )
        #expect(row.resolution == .unresolved)
        #expect(result.summary.unresolvedCount == 1)
    }

    @Test("New rows use only a current same-direction category default")
    func newRowsUseValidDirectionDefaults() {
        let result = reconcile(
            candidates: [
                candidate(id: importA, kind: .expense, note: "Synthetic expense"),
                candidate(id: importB, kind: .income, note: "Synthetic income"),
            ],
            categories: [
                category(id: expenseCategoryID, kind: .expense),
                category(id: incomeCategoryID, kind: .income),
            ],
            defaults: StatementImportCategoryDefaults(
                expenseCategoryID: expenseCategoryID,
                incomeCategoryID: incomeCategoryID
            )
        )

        #expect(result.rows[0].disposition == .newTransaction)
        #expect(
            result.rows[0].resolution
                == .transaction(categoryID: expenseCategoryID, note: "Synthetic expense")
        )
        #expect(
            result.rows[1].resolution
                == .transaction(categoryID: incomeCategoryID, note: "Synthetic income")
        )
        #expect(result.summary.newTransactionCount == 2)
    }

    @Test("Missing, stale, and wrong-direction defaults leave new rows unresolved")
    func invalidDefaultsStayUnresolved() {
        let result = reconcile(
            candidates: [
                candidate(id: importA, kind: .expense),
                candidate(id: importB, kind: .income),
                candidate(id: String(repeating: "c", count: 64), kind: .expense),
            ],
            categories: [category(id: incomeCategoryID, kind: .income)],
            defaults: StatementImportCategoryDefaults(
                expenseCategoryID: incomeCategoryID,
                incomeCategoryID: UUID()
            )
        )

        #expect(result.rows.allSatisfy { $0.disposition == .newTransaction })
        #expect(result.rows.allSatisfy { $0.resolution == .unresolved })
        #expect(result.summary.unresolvedCount == 3)
    }

    @Test("Candidate order is preserved while possible match order is stable")
    func outputIsDeterministic() {
        let first = candidate(id: importB, amount: 100_000)
        let second = candidate(id: importA, amount: 200_000)

        let result = reconcile(candidates: [first, second])

        #expect(result.rows.map(\.id) == [importB, importA])
    }

    @Test("Invalid candidate or statement account cannot become a selected new row")
    func invalidSourceInputsStayUnresolved() {
        let invalidCandidate = reconcile(candidates: [candidate(id: "invalid")])
        let missingAccount = reconcile(
            candidates: [candidate(id: importA)],
            statementAccountID: UUID()
        )

        #expect(invalidCandidate.rows.first?.resolution == .unresolved)
        #expect(missingAccount.rows.first?.resolution == .unresolved)
    }

    private func reconcile(
        candidates: [BankTransactionCandidate],
        statementAccountID: UUID? = nil,
        categories: [StatementImportCategorySnapshot]? = nil,
        transactions: [StatementImportTransactionSnapshot] = [],
        transfers: [StatementImportTransferSnapshot] = [],
        defaults: StatementImportCategoryDefaults? = nil,
        calendar: Calendar? = nil
    ) -> StatementImportReconciliation {
        StatementImportReconciler.reconcile(
            candidates: candidates,
            statementCurrencyCode: VNDCurrency.code,
            statementAccountID: statementAccountID ?? accountID,
            accounts: [
                StatementImportAccountSnapshot(id: accountID, currencyCode: VNDCurrency.code),
                StatementImportAccountSnapshot(id: otherAccountID, currencyCode: VNDCurrency.code),
            ],
            categories: categories
                ?? [category(id: expenseCategoryID, kind: .expense)],
            transactions: transactions,
            transfers: transfers,
            defaults: defaults
                ?? StatementImportCategoryDefaults(
                    expenseCategoryID: expenseCategoryID,
                    incomeCategoryID: nil
                ),
            calendar: calendar ?? StatementImportReconciler.vietnamCalendar
        )
    }

    private func candidate(
        id: String,
        occurredAt: Date? = nil,
        kind: TransactionKind = .expense,
        amount: Decimal = 125_000,
        note: String = "Synthetic note"
    ) -> BankTransactionCandidate {
        BankTransactionCandidate(
            id: id,
            occurredAt: occurredAt ?? candidateTime,
            kind: kind,
            amount: amount,
            note: note,
            sourceReference: "SYNTHETIC-REFERENCE",
            sourcePage: 1
        )
    }

    private func category(
        id: UUID,
        kind: TransactionKind
    ) -> StatementImportCategorySnapshot {
        StatementImportCategorySnapshot(id: id, kind: kind)
    }

    private func transaction(
        id: UUID,
        accountID: UUID? = nil,
        kind: TransactionKind = .expense,
        amount: Decimal = 125_000,
        occurredAt: Date? = nil,
        currencyCode: String = VNDCurrency.code,
        sourceImportID: String? = nil,
        note: String = "Synthetic existing note"
    ) -> StatementImportTransactionSnapshot {
        StatementImportTransactionSnapshot(
            id: id,
            kind: kind,
            amount: amount,
            occurredAt: occurredAt ?? candidateTime,
            note: note,
            accountID: accountID ?? self.accountID,
            currencyCode: currencyCode,
            sourceImportID: sourceImportID
        )
    }

    private func transfer(
        id: UUID,
        amount: Decimal = 125_000,
        occurredAt: Date? = nil,
        sourceAccountID: UUID? = nil,
        destinationAccountID: UUID? = nil,
        currencyCode: String = VNDCurrency.code,
        sourceAccountImportID: String? = nil,
        destinationAccountImportID: String? = nil
    ) -> StatementImportTransferSnapshot {
        StatementImportTransferSnapshot(
            id: id,
            amount: amount,
            occurredAt: occurredAt ?? candidateTime,
            sourceAccountID: sourceAccountID ?? accountID,
            destinationAccountID: destinationAccountID ?? otherAccountID,
            currencyCode: currencyCode,
            sourceAccountImportID: sourceAccountImportID,
            destinationAccountImportID: destinationAccountImportID
        )
    }

    private func vietnamCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        return calendar
    }
}
