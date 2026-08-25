import Foundation
import SwiftData

struct StatementImportCommitRequest: Sendable {
    let statement: ParsedBankStatement
    let statementAccountID: UUID
    let rows: [ReconciledImportRow]
}

struct StatementImportCommitReport: Equatable, Sendable {
    var createdTransactionCount = 0
    var linkedCount = 0
    var alreadyImportedCount = 0
    var skippedCount = 0
}

enum StatementImportCommitError: Error, Equatable, Sendable {
    case invalidRequest
    case staleReview
    case storeFailure
}

@MainActor
struct StatementImportCommitService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func commit(_ request: StatementImportCommitRequest) throws -> StatementImportCommitReport {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        do {
            return try commit(request, in: context)
        } catch let error as StatementImportCommitError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw StatementImportCommitError.storeFailure
        }
    }

    private func commit(
        _ request: StatementImportCommitRequest,
        in context: ModelContext
    ) throws -> StatementImportCommitReport {
        let candidates = request.statement.candidates
        guard request.statement.isComplete,
            request.statement.currencyCode == VNDCurrency.code,
            request.rows.map(\.candidate) == candidates,
            Set(candidates.map(\.id)).count == candidates.count,
            candidates.allSatisfy({ ImportSourceID(rawValue: $0.id) != nil })
        else {
            throw StatementImportCommitError.invalidRequest
        }

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let statementAccountIsValid = accounts.contains {
            $0.id == request.statementAccountID && $0.currencyCode == VNDCurrency.code
        }
        guard statementAccountIsValid else {
            throw StatementImportCommitError.invalidRequest
        }

        let current = StatementImportReconciler.reconcile(
            candidates: candidates,
            statementCurrencyCode: request.statement.currencyCode,
            statementAccountID: request.statementAccountID,
            accounts: accounts.map {
                StatementImportAccountSnapshot(id: $0.id, currencyCode: $0.currencyCode)
            },
            categories: categories.map {
                StatementImportCategorySnapshot(id: $0.id, kind: $0.kind)
            },
            transactions: transactions.map {
                StatementImportTransactionSnapshot(
                    id: $0.id,
                    kind: $0.kind,
                    amount: $0.amount,
                    occurredAt: $0.occurredAt,
                    note: $0.note,
                    accountID: $0.accountID,
                    currencyCode: $0.currencyCode,
                    sourceImportID: $0.sourceImportID
                )
            },
            transfers: transfers.map {
                StatementImportTransferSnapshot(
                    id: $0.id,
                    amount: $0.amount,
                    occurredAt: $0.occurredAt,
                    sourceAccountID: $0.sourceAccountID,
                    destinationAccountID: $0.destinationAccountID,
                    currencyCode: $0.currencyCode,
                    sourceAccountImportID: $0.sourceAccountImportID,
                    destinationAccountImportID: $0.destinationAccountImportID,
                    note: $0.note
                )
            },
            defaults: StatementImportCategoryDefaults(
                expenseCategoryID: nil,
                incomeCategoryID: nil
            ),
            calendar: StatementImportReconciler.vietnamCalendar
        )

        let transactionByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var newTransactions: [MoneyTransaction] = []
        var linkedTransactions: [(MoneyTransaction, ImportSourceID)] = []
        var linkedTargetIDs: Set<UUID> = []
        var report = StatementImportCommitReport()
        let createdAt = Date()

        for (requestedRow, currentRow) in zip(request.rows, current.rows) {
            if currentRow.disposition.isExact {
                report.alreadyImportedCount += 1
                continue
            }

            let sourceID = try validatedSourceID(for: requestedRow.candidate)
            switch requestedRow.resolution {
            case let .transaction(categoryID, note):
                guard let category = categoryByID[categoryID],
                    category.kind == requestedRow.candidate.kind
                else {
                    throw StatementImportCommitError.invalidRequest
                }

                let draft = TransactionDraft(
                    kind: requestedRow.candidate.kind,
                    amountText: VNDCurrency.formatPlain(requestedRow.candidate.amount),
                    occurredAt: requestedRow.candidate.occurredAt,
                    note: note,
                    accountID: request.statementAccountID,
                    categoryID: categoryID
                )
                let transaction: MoneyTransaction
                do {
                    transaction = try draft.makeTransaction(id: UUID(), createdAt: createdAt)
                } catch {
                    throw StatementImportCommitError.invalidRequest
                }
                transaction.sourceImportID = sourceID.rawValue
                newTransactions.append(transaction)
                report.createdTransactionCount += 1

            case let .linkTransaction(transactionID):
                guard case let .possibleMatches(transactionIDs, _) = currentRow.disposition,
                    transactionIDs.contains(transactionID),
                    linkedTargetIDs.insert(transactionID).inserted,
                    let transaction = transactionByID[transactionID],
                    transaction.sourceImportID == nil
                else {
                    throw StatementImportCommitError.staleReview
                }
                linkedTransactions.append((transaction, sourceID))
                report.linkedCount += 1

            case .skip:
                report.skippedCount += 1

            case .alreadyImported:
                throw StatementImportCommitError.staleReview

            case .newTransfer, .linkTransfer, .unresolved:
                throw StatementImportCommitError.invalidRequest
            }
        }

        for transaction in newTransactions {
            context.insert(transaction)
        }
        for (transaction, sourceID) in linkedTransactions {
            transaction.sourceImportID = sourceID.rawValue
        }
        if !newTransactions.isEmpty || !linkedTransactions.isEmpty {
            try context.save()
        }

        return report
    }

    private func validatedSourceID(
        for candidate: BankTransactionCandidate
    ) throws -> ImportSourceID {
        guard let sourceID = ImportSourceID(rawValue: candidate.id) else {
            throw StatementImportCommitError.invalidRequest
        }
        return sourceID
    }
}
