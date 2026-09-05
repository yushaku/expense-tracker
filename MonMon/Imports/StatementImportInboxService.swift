import Foundation

struct StatementImportPreview: Sendable, Equatable {
    let staged: StagedBankStatement
    let statement: ParsedBankStatement
}

enum StatementImportCompletion: Equatable, Sendable {
    case completed(StatementImportCommitReport)
    case cleanupNeeded(StatementImportCommitReport)
}

struct StatementImportInboxService: Sendable {
    private let store: StatementIntakeStore
    private let parser: any BankStatementParsing
    private let removeStatement: @Sendable (StagedBankStatement) throws -> Void

    init(
        rootURL: URL,
        parser: any BankStatementParsing = TPBankPDFStatementParser(),
        removeStatement: (@Sendable (StagedBankStatement) throws -> Void)? = nil
    ) {
        let store = StatementIntakeStore(rootURL: rootURL)
        self.store = store
        self.parser = parser
        self.removeStatement = removeStatement ?? { try store.remove($0) }
    }

    static func live(
        containerURL: @escaping @Sendable () -> URL? = {
            // The Mac test host must not resolve the App Group container: see
            // `MonMonProcess.isRunningUnitTests`. Spending still launches, and
            // `StatementImportInbox.live()` swallows this as unavailable.
            guard !MonMonProcess.isRunningUnitTests else {
                return nil
            }
            guard let appGroupIdentifier = StatementInboxConfiguration.appGroupIdentifier else {
                return nil
            }
            return FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )
        }
    ) throws -> StatementImportInboxService {
        guard let rootURL = containerURL() else {
            throw StatementIntakeError.appGroupUnavailable
        }
        return StatementImportInboxService(rootURL: rootURL)
    }

    func pendingStatements() throws -> [StagedBankStatement] {
        try store.pendingStatements()
    }

    func preview(_ staged: StagedBankStatement) async throws -> StatementImportPreview {
        let store = store
        let parser = parser
        return try await Task.detached(priority: .userInitiated) {
            let data = try store.data(for: staged)
            return StatementImportPreview(
                staged: staged,
                statement: try parser.parse(data)
            )
        }.value
    }

    func remove(_ staged: StagedBankStatement) throws {
        try removeStatement(staged)
    }

    @MainActor
    func completeImport(
        _ request: StatementImportCommitRequest,
        staged: StagedBankStatement,
        commitService: StatementImportCommitService,
        accountMapping: StatementAccountMapping
    ) throws -> StatementImportCompletion {
        let report = try commitService.commit(request)
        accountMapping.remember(
            accountID: request.statementAccountID,
            bank: request.statement.bank,
            accountLastFour: request.statement.accountLastFour,
            accounts: [
                StatementImportAccountSnapshot(
                    id: request.statementAccountID,
                    currencyCode: request.statement.currencyCode
                )
            ],
            financialCommitSucceeded: true
        )

        do {
            try remove(staged)
            return .completed(report)
        } catch {
            return .cleanupNeeded(report)
        }
    }

    func retryCleanup(_ staged: StagedBankStatement) -> Bool {
        do {
            try remove(staged)
            return true
        } catch {
            return false
        }
    }
}
