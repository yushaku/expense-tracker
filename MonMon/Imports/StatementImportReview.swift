import Foundation
import Observation

struct StatementImportReviewSnapshot: Equatable, Sendable {
    let accounts: [StatementImportAccountSnapshot]
    let categories: [StatementImportCategorySnapshot]
    let transactions: [StatementImportTransactionSnapshot]
    let transfers: [StatementImportTransferSnapshot]
    let defaults: StatementImportCategoryDefaults
    let defaultAccountID: UUID?

    init(
        accounts: [StatementImportAccountSnapshot],
        categories: [StatementImportCategorySnapshot],
        transactions: [StatementImportTransactionSnapshot],
        transfers: [StatementImportTransferSnapshot],
        defaults: StatementImportCategoryDefaults,
        defaultAccountID: UUID? = nil
    ) {
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.transfers = transfers
        self.defaults = defaults
        self.defaultAccountID = defaultAccountID
    }
}

enum StatementImportReviewFailure: Equatable, Sendable {
    case invalidReview
    case staleReview
    case storeFailure
    case unknown
}

enum StatementImportReviewPhase: Equatable, Sendable {
    case reviewing
    case committing
    case saved(StatementImportCommitReport)
    case cleanupNeeded(StatementImportCommitReport)
    case failed(StatementImportReviewFailure)
}

struct StatementImportCommitConfirmation: Equatable, Sendable {
    let summary: StatementImportSummary
    let recordCount: Int
    let removesReviewedStatement: Bool
}

@MainActor
@Observable
final class StatementImportReview {
    private(set) var staged: StagedBankStatement
    private(set) var statement: ParsedBankStatement
    private(set) var statementAccountID: UUID?
    private(set) var rows: [ReconciledImportRow] = []
    private(set) var phase: StatementImportReviewPhase = .reviewing

    @ObservationIgnored private var snapshot: StatementImportReviewSnapshot
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let complete:
        @MainActor @Sendable (
            StatementImportCommitRequest,
            StagedBankStatement
        ) async throws -> StatementImportCompletion
    @ObservationIgnored private let cleanup:
        @MainActor @Sendable (StagedBankStatement) async -> Bool

    init(
        preview: StatementImportPreview,
        snapshot: StatementImportReviewSnapshot,
        accountMapping: StatementAccountMapping,
        complete:
            @MainActor @Sendable @escaping (
                StatementImportCommitRequest,
                StagedBankStatement
            ) async throws -> StatementImportCompletion,
        retryCleanup: @MainActor @Sendable @escaping (StagedBankStatement) async -> Bool
    ) {
        staged = preview.staged
        statement = preview.statement
        self.snapshot = snapshot
        self.complete = complete
        cleanup = retryCleanup
        statementAccountID = Self.initialStatementAccountID(
            for: preview.statement,
            snapshot: snapshot,
            accountMapping: accountMapping
        )
        rebuildRows(preserving: [:])
    }

    var summary: StatementImportSummary {
        StatementImportSummary(rows: rows)
    }

    var visibleRows: [ReconciledImportRow] {
        rows.filter {
            if case .skip = $0.resolution {
                return false
            }
            return true
        }
    }

    var commitConfirmation: StatementImportCommitConfirmation? {
        guard isCommitReady else { return nil }
        let summary = summary
        return StatementImportCommitConfirmation(
            summary: summary,
            recordCount: summary.newTransactionCount
                + summary.newTransferCount
                + summary.linkedCount,
            removesReviewedStatement: rows.allSatisfy(\.disposition.isExact)
        )
    }

    var isEditingAllowed: Bool {
        switch phase {
        case .reviewing, .failed:
            true
        case .committing, .saved, .cleanupNeeded:
            false
        }
    }

    var isCommitReady: Bool {
        let canStartCommit: Bool
        switch phase {
        case .reviewing, .failed:
            canStartCommit = true
        case .committing, .saved, .cleanupNeeded:
            canStartCommit = false
        }
        guard canStartCommit,
            statement.isComplete,
            let statementAccountID,
            snapshot.accounts.contains(where: {
                $0.id == statementAccountID && $0.currencyCode == VNDCurrency.code
            }),
            rows.map(\.candidate) == statement.candidates
        else {
            return false
        }

        return rows.allSatisfy {
            resolutionIsValid($0.resolution, for: $0, statementAccountID: statementAccountID)
        }
    }

    func selectStatementAccount(_ accountID: UUID?) {
        guard isEditingAllowed else { return }
        let choices = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.resolution) })
        statementAccountID = accountID
        phase = .reviewing
        generation = UUID()
        rebuildRows(preserving: choices)
    }

    func setResolution(_ resolution: ImportRowResolution, forCandidateID candidateID: String) {
        guard isEditingAllowed,
            let index = rows.firstIndex(where: { $0.id == candidateID }),
            !rows[index].disposition.isExact
        else {
            return
        }
        rows[index].resolution = resolution
        phase = .reviewing
        generation = UUID()
    }

    func replace(
        preview: StatementImportPreview,
        snapshot: StatementImportReviewSnapshot,
        accountMapping: StatementAccountMapping
    ) {
        generation = UUID()
        staged = preview.staged
        statement = preview.statement
        self.snapshot = snapshot
        statementAccountID = Self.initialStatementAccountID(
            for: preview.statement,
            snapshot: snapshot,
            accountMapping: accountMapping
        )
        phase = .reviewing
        rebuildRows(preserving: [:])
    }

    func commit() async {
        switch phase {
        case .committing, .saved, .cleanupNeeded:
            return
        case .reviewing, .failed:
            break
        }
        guard isCommitReady, let statementAccountID else {
            phase = .failed(.invalidReview)
            return
        }

        let expectedGeneration = generation
        let expectedStagedID = staged.id
        let request = StatementImportCommitRequest(
            statement: statement,
            statementAccountID: statementAccountID,
            rows: rows
        )
        phase = .committing
        do {
            let result = try await complete(request, staged)
            guard generation == expectedGeneration, staged.id == expectedStagedID else {
                return
            }
            switch result {
            case .completed(let report):
                phase = .saved(report)
            case .cleanupNeeded(let report):
                phase = .cleanupNeeded(report)
            }
        } catch {
            guard generation == expectedGeneration, staged.id == expectedStagedID else {
                return
            }
            phase = .failed(reviewFailure(for: error))
        }
    }

    func retryCleanup() async {
        guard case let .cleanupNeeded(report) = phase else { return }
        let expectedGeneration = generation
        let expectedStagedID = staged.id
        phase = .committing
        let succeeded = await cleanup(staged)
        guard generation == expectedGeneration, staged.id == expectedStagedID else {
            return
        }
        phase = succeeded ? .saved(report) : .cleanupNeeded(report)
    }

    private static func initialStatementAccountID(
        for statement: ParsedBankStatement,
        snapshot: StatementImportReviewSnapshot,
        accountMapping: StatementAccountMapping
    ) -> UUID? {
        if let rememberedAccountID = accountMapping.resolve(
            bank: statement.bank,
            accountLastFour: statement.accountLastFour,
            accounts: snapshot.accounts
        ) {
            return rememberedAccountID
        }

        guard let defaultAccountID = snapshot.defaultAccountID else { return nil }
        return snapshot.accounts.first {
            $0.id == defaultAccountID && $0.currencyCode == VNDCurrency.code
        }?.id
    }

    private func rebuildRows(preserving choices: [String: ImportRowResolution]) {
        guard let statementAccountID else {
            rows = statement.candidates.map {
                ReconciledImportRow(
                    candidate: $0,
                    disposition: .newTransaction,
                    resolution: .unresolved
                )
            }
            return
        }

        let reconciliation = StatementImportReconciler.reconcile(
            candidates: statement.candidates,
            statementCurrencyCode: statement.currencyCode,
            statementAccountID: statementAccountID,
            accounts: snapshot.accounts,
            categories: snapshot.categories,
            transactions: snapshot.transactions,
            transfers: snapshot.transfers,
            defaults: snapshot.defaults,
            calendar: StatementImportReconciler.vietnamCalendar
        )
        rows = reconciliation.rows.map { row in
            guard !row.disposition.isExact,
                let choice = choices[row.id],
                resolutionIsValid(choice, for: row, statementAccountID: statementAccountID)
            else {
                return row
            }
            var preserved = row
            preserved.resolution = choice
            return preserved
        }
    }

    private func resolutionIsValid(
        _ resolution: ImportRowResolution,
        for row: ReconciledImportRow,
        statementAccountID: UUID
    ) -> Bool {
        if row.disposition.isExact {
            return resolution == .alreadyImported
        }

        switch resolution {
        case let .transaction(categoryID, _):
            return snapshot.categories.contains {
                $0.id == categoryID && $0.kind == row.candidate.kind
            }
        case let .newTransfer(otherAccountID, _):
            return otherAccountID != statementAccountID
                && snapshot.accounts.contains {
                    $0.id == otherAccountID && $0.currencyCode == VNDCurrency.code
                }
        case let .linkTransaction(transactionID):
            guard case let .possibleMatches(transactionIDs, _) = row.disposition else {
                return false
            }
            return transactionIDs.contains(transactionID)
        case let .linkTransfer(transferID):
            guard case let .possibleMatches(_, transferIDs) = row.disposition else {
                return false
            }
            return transferIDs.contains(transferID)
        case .skip:
            return true
        case .alreadyImported, .unresolved:
            return false
        }
    }

    private func reviewFailure(for error: Error) -> StatementImportReviewFailure {
        guard let commitError = error as? StatementImportCommitError else {
            return .unknown
        }
        switch commitError {
        case .invalidRequest:
            return .invalidReview
        case .staleReview:
            return .staleReview
        case .storeFailure:
            return .storeFailure
        }
    }
}
