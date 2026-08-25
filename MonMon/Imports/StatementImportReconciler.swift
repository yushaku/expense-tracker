import Foundation

struct StatementImportAccountSnapshot: Equatable, Sendable {
    let id: UUID
    let currencyCode: String
}

struct StatementImportCategorySnapshot: Equatable, Sendable {
    let id: UUID
    let kind: TransactionKind
}

struct StatementImportTransactionSnapshot: Equatable, Sendable {
    let id: UUID
    let kind: TransactionKind
    let amount: Decimal
    let occurredAt: Date
    let note: String
    let accountID: UUID
    let currencyCode: String
    let sourceImportID: String?
}

struct StatementImportTransferSnapshot: Equatable, Sendable {
    let id: UUID
    let amount: Decimal
    let occurredAt: Date
    let sourceAccountID: UUID
    let destinationAccountID: UUID
    let currencyCode: String
    let sourceAccountImportID: String?
    let destinationAccountImportID: String?
    let note: String

    init(
        id: UUID,
        amount: Decimal,
        occurredAt: Date,
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        currencyCode: String,
        sourceAccountImportID: String?,
        destinationAccountImportID: String?,
        note: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.occurredAt = occurredAt
        self.sourceAccountID = sourceAccountID
        self.destinationAccountID = destinationAccountID
        self.currencyCode = currencyCode
        self.sourceAccountImportID = sourceAccountImportID
        self.destinationAccountImportID = destinationAccountImportID
        self.note = note
    }
}

struct StatementImportCategoryDefaults: Equatable, Sendable {
    let expenseCategoryID: UUID?
    let incomeCategoryID: UUID?

    func categoryID(for kind: TransactionKind) -> UUID? {
        switch kind {
        case .expense:
            expenseCategoryID
        case .income:
            incomeCategoryID
        }
    }
}

enum ImportCandidateDisposition: Equatable, Sendable {
    case newTransaction
    case exactImportedTransaction(transactionID: UUID)
    case possibleMatches(transactionIDs: [UUID], transferIDs: [UUID])
    case exactTransfer(transferID: UUID)

    var isExact: Bool {
        switch self {
        case .exactImportedTransaction, .exactTransfer:
            true
        case .newTransaction, .possibleMatches:
            false
        }
    }
}

enum ImportRowResolution: Equatable, Sendable {
    case transaction(categoryID: UUID, note: String)
    case newTransfer(otherAccountID: UUID, note: String)
    case linkTransaction(transactionID: UUID)
    case linkTransfer(transferID: UUID)
    case skip
    case alreadyImported
    case unresolved
}

struct ReconciledImportRow: Identifiable, Equatable, Sendable {
    var id: String { candidate.id }

    let candidate: BankTransactionCandidate
    let disposition: ImportCandidateDisposition
    var resolution: ImportRowResolution
}

struct StatementImportSummary: Equatable, Sendable {
    var newTransactionCount = 0
    var newTransferCount = 0
    var linkedCount = 0
    var alreadyImportedCount = 0
    var skippedCount = 0
    var unresolvedCount = 0

    init(rows: [ReconciledImportRow]) {
        for row in rows {
            if row.disposition.isExact {
                alreadyImportedCount += 1
                continue
            }

            switch row.resolution {
            case .transaction:
                newTransactionCount += 1
            case .newTransfer:
                newTransferCount += 1
            case .linkTransaction, .linkTransfer:
                linkedCount += 1
            case .skip:
                skippedCount += 1
            case .alreadyImported:
                alreadyImportedCount += 1
            case .unresolved:
                unresolvedCount += 1
            }
        }
    }
}

struct StatementImportReconciliation: Equatable, Sendable {
    var rows: [ReconciledImportRow]

    var summary: StatementImportSummary {
        StatementImportSummary(rows: rows)
    }
}

enum StatementImportReconciler {
    static var vietnamCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .gmt
        return calendar
    }

    static func reconcile(
        candidates: [BankTransactionCandidate],
        statementCurrencyCode: String,
        statementAccountID: UUID,
        accounts: [StatementImportAccountSnapshot],
        categories: [StatementImportCategorySnapshot],
        transactions: [StatementImportTransactionSnapshot],
        transfers: [StatementImportTransferSnapshot],
        defaults: StatementImportCategoryDefaults,
        calendar: Calendar
    ) -> StatementImportReconciliation {
        let statementAccountIsValid = accounts.contains {
            $0.id == statementAccountID && $0.currencyCode == statementCurrencyCode
                && $0.currencyCode == VNDCurrency.code
        }

        let rows = candidates.map { candidate in
            reconcile(
                candidate,
                statementCurrencyCode: statementCurrencyCode,
                statementAccountID: statementAccountID,
                statementAccountIsValid: statementAccountIsValid,
                categories: categories,
                transactions: transactions,
                transfers: transfers,
                defaults: defaults,
                calendar: calendar
            )
        }
        return StatementImportReconciliation(rows: rows)
    }

    private static func reconcile(
        _ candidate: BankTransactionCandidate,
        statementCurrencyCode: String,
        statementAccountID: UUID,
        statementAccountIsValid: Bool,
        categories: [StatementImportCategorySnapshot],
        transactions: [StatementImportTransactionSnapshot],
        transfers: [StatementImportTransferSnapshot],
        defaults: StatementImportCategoryDefaults,
        calendar: Calendar
    ) -> ReconciledImportRow {
        let sourceID = ImportSourceID(rawValue: candidate.id)

        if let sourceID,
            let transactionID = exactTransactionID(sourceID, in: transactions)
        {
            return ReconciledImportRow(
                candidate: candidate,
                disposition: .exactImportedTransaction(transactionID: transactionID),
                resolution: .alreadyImported
            )
        }

        if let sourceID,
            let transferID = exactTransferID(
                sourceID,
                candidateKind: candidate.kind,
                statementAccountID: statementAccountID,
                transfers: transfers
            )
        {
            return ReconciledImportRow(
                candidate: candidate,
                disposition: .exactTransfer(transferID: transferID),
                resolution: .alreadyImported
            )
        }

        guard sourceID != nil,
            statementAccountIsValid,
            statementCurrencyCode == VNDCurrency.code,
            candidate.amount > 0
        else {
            return ReconciledImportRow(
                candidate: candidate,
                disposition: .newTransaction,
                resolution: .unresolved
            )
        }

        let transactionIDs = possibleTransactionIDs(
            for: candidate,
            statementAccountID: statementAccountID,
            statementCurrencyCode: statementCurrencyCode,
            transactions: transactions,
            calendar: calendar
        )
        let transferIDs = possibleTransferIDs(
            for: candidate,
            statementAccountID: statementAccountID,
            statementCurrencyCode: statementCurrencyCode,
            transfers: transfers,
            calendar: calendar
        )
        if !transactionIDs.isEmpty || !transferIDs.isEmpty {
            return ReconciledImportRow(
                candidate: candidate,
                disposition: .possibleMatches(
                    transactionIDs: transactionIDs,
                    transferIDs: transferIDs
                ),
                resolution: .unresolved
            )
        }

        let categoryID = defaults.categoryID(for: candidate.kind).flatMap { defaultID in
            categories.first { $0.id == defaultID && $0.kind == candidate.kind }?.id
        }
        return ReconciledImportRow(
            candidate: candidate,
            disposition: .newTransaction,
            resolution: categoryID.map {
                .transaction(categoryID: $0, note: candidate.note)
            } ?? .unresolved
        )
    }

    private static func exactTransactionID(
        _ sourceID: ImportSourceID,
        in transactions: [StatementImportTransactionSnapshot]
    ) -> UUID? {
        transactions
            .filter {
                $0.sourceImportID.flatMap(ImportSourceID.init(rawValue:)) == sourceID
            }
            .map(\.id)
            .sorted(by: uuidComesBefore)
            .first
    }

    private static func exactTransferID(
        _ sourceID: ImportSourceID,
        candidateKind: TransactionKind,
        statementAccountID: UUID,
        transfers: [StatementImportTransferSnapshot]
    ) -> UUID? {
        transfers
            .filter { transfer in
                switch candidateKind {
                case .expense:
                    transfer.sourceAccountID == statementAccountID
                        && transfer.sourceAccountImportID.flatMap(
                            ImportSourceID.init(rawValue:)
                        ) == sourceID
                case .income:
                    transfer.destinationAccountID == statementAccountID
                        && transfer.destinationAccountImportID.flatMap(
                            ImportSourceID.init(rawValue:)
                        ) == sourceID
                }
            }
            .map(\.id)
            .sorted(by: uuidComesBefore)
            .first
    }

    private static func possibleTransactionIDs(
        for candidate: BankTransactionCandidate,
        statementAccountID: UUID,
        statementCurrencyCode: String,
        transactions: [StatementImportTransactionSnapshot],
        calendar: Calendar
    ) -> [UUID] {
        transactions
            .filter {
                $0.sourceImportID == nil
                    && $0.accountID == statementAccountID
                    && $0.kind == candidate.kind
                    && $0.amount == candidate.amount
                    && $0.currencyCode == statementCurrencyCode
                    && $0.currencyCode == VNDCurrency.code
                    && calendar.isDate($0.occurredAt, inSameDayAs: candidate.occurredAt)
            }
            .map(\.id)
            .sorted(by: uuidComesBefore)
    }

    private static func possibleTransferIDs(
        for candidate: BankTransactionCandidate,
        statementAccountID: UUID,
        statementCurrencyCode: String,
        transfers: [StatementImportTransferSnapshot],
        calendar: Calendar
    ) -> [UUID] {
        transfers
            .filter { transfer in
                guard transfer.amount == candidate.amount,
                    transfer.currencyCode == statementCurrencyCode,
                    transfer.currencyCode == VNDCurrency.code,
                    calendar.isDate(transfer.occurredAt, inSameDayAs: candidate.occurredAt)
                else {
                    return false
                }

                switch candidate.kind {
                case .expense:
                    return transfer.sourceAccountID == statementAccountID
                        && transfer.sourceAccountImportID == nil
                case .income:
                    return transfer.destinationAccountID == statementAccountID
                        && transfer.destinationAccountImportID == nil
                }
            }
            .map(\.id)
            .sorted(by: uuidComesBefore)
    }

    private static func uuidComesBefore(_ left: UUID, _ right: UUID) -> Bool {
        left.uuidString < right.uuidString
    }
}
