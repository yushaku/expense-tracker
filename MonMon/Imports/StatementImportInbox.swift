import Foundation
import Observation

protocol StatementImportInboxServing: Sendable {
    func loadPendingStatements() async throws -> [StagedBankStatement]
    func loadPreview(_ staged: StagedBankStatement) async throws -> StatementImportPreview
    func removeStatement(_ staged: StagedBankStatement) async throws
}

extension StatementImportInboxService: StatementImportInboxServing {
    func loadPendingStatements() async throws -> [StagedBankStatement] {
        let service = self
        return try await Task.detached(priority: .userInitiated) {
            try service.pendingStatements()
        }.value
    }

    func loadPreview(_ staged: StagedBankStatement) async throws -> StatementImportPreview {
        try await preview(staged)
    }

    func removeStatement(_ staged: StagedBankStatement) async throws {
        let service = self
        try await Task.detached(priority: .userInitiated) {
            try service.remove(staged)
        }.value
    }
}

enum StatementImportFailure: Sendable, Equatable {
    case appGroupUnavailable
    case unsupportedPDF
    case oversizedFile
    case unreadableInput
    case malformedStagedItem
    case fileSystem
    case unsupportedFormat
    case encryptedDocument
    case missingTextLayer
    case unrecognizedLayout
    case invalidStatementMetadata
    case noTransactionRows
    case unknown

    static func map(_ error: Error) -> StatementImportFailure {
        if let intakeError = error as? StatementIntakeError {
            switch intakeError {
            case .appGroupUnavailable:
                return .appGroupUnavailable
            case .unsupportedPDF:
                return .unsupportedPDF
            case .oversizedFile:
                return .oversizedFile
            case .unreadableInput:
                return .unreadableInput
            case .malformedStagedItem:
                return .malformedStagedItem
            case .fileSystem:
                return .fileSystem
            }
        }

        if let parserError = error as? BankStatementParserError {
            switch parserError {
            case .unsupportedFormat:
                return .unsupportedFormat
            case .encryptedDocument:
                return .encryptedDocument
            case .missingTextLayer:
                return .missingTextLayer
            case .unrecognizedLayout:
                return .unrecognizedLayout
            case .invalidStatementMetadata:
                return .invalidStatementMetadata
            case .noTransactionRows:
                return .noTransactionRows
            }
        }

        return .unknown
    }
}

enum StatementInboxListPhase: Sendable, Equatable {
    case idle
    case loading
    case loaded([StagedBankStatement])
    case failed(StatementImportFailure)
}

enum StatementInboxPreviewPhase: Sendable, Equatable {
    case idle
    case loading(StagedBankStatement)
    case loaded(StatementImportPreview)
    case failed(staged: StagedBankStatement, failure: StatementImportFailure)
}

@MainActor
@Observable
final class StatementImportInbox {
    private(set) var listPhase: StatementInboxListPhase
    private(set) var previewPhase: StatementInboxPreviewPhase = .idle

    private let service: (any StatementImportInboxServing)?
    private var selectedStatementID: String?

    init(service: any StatementImportInboxServing) {
        self.service = service
        listPhase = .idle
    }

    private init(startupFailure: StatementImportFailure) {
        service = nil
        listPhase = .failed(startupFailure)
    }

    static func live() -> StatementImportInbox {
        do {
            return StatementImportInbox(service: try StatementImportInboxService.live())
        } catch {
            return StatementImportInbox(startupFailure: .map(error))
        }
    }

    var pendingStatements: [StagedBankStatement] {
        guard case .loaded(let statements) = listPhase else {
            return []
        }
        return statements
    }

    var pendingCount: Int? {
        guard case .loaded(let statements) = listPhase else {
            return nil
        }
        return statements.count
    }

    func refresh() async {
        guard let service else {
            return
        }

        listPhase = .loading
        do {
            listPhase = .loaded(try await service.loadPendingStatements())
        } catch {
            listPhase = .failed(.map(error))
        }
    }

    func loadPreview(_ staged: StagedBankStatement) async {
        guard let service else {
            previewPhase = .failed(staged: staged, failure: .appGroupUnavailable)
            return
        }

        selectedStatementID = staged.id
        previewPhase = .loading(staged)
        do {
            let preview = try await service.loadPreview(staged)
            guard selectedStatementID == staged.id else {
                return
            }
            previewPhase = .loaded(preview)
        } catch {
            guard selectedStatementID == staged.id else {
                return
            }
            previewPhase = .failed(staged: staged, failure: .map(error))
        }
    }

    func clearPreview() {
        selectedStatementID = nil
        previewPhase = .idle
    }

    func remove(_ staged: StagedBankStatement) async -> Bool {
        guard let service else {
            previewPhase = .failed(staged: staged, failure: .appGroupUnavailable)
            return false
        }

        do {
            try await service.removeStatement(staged)
            if selectedStatementID == staged.id {
                clearPreview()
            }
            await refresh()
            return true
        } catch {
            guard selectedStatementID == staged.id else {
                return false
            }
            previewPhase = .failed(staged: staged, failure: .map(error))
            return false
        }
    }
}
