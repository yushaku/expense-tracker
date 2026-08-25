import Foundation

struct StatementImportPreview: Sendable, Equatable {
    let staged: StagedBankStatement
    let statement: ParsedBankStatement
}

struct StatementImportInboxService: Sendable {
    private let store: StatementIntakeStore
    private let parser: any BankStatementParsing

    init(
        rootURL: URL,
        parser: any BankStatementParsing = TPBankPDFStatementParser()
    ) {
        store = StatementIntakeStore(rootURL: rootURL)
        self.parser = parser
    }

    static func live(
        containerURL: @escaping @Sendable () -> URL? = {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier:
                    StatementInboxConfiguration.appGroupIdentifier
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
        try store.remove(staged)
    }
}
