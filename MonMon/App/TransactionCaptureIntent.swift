import AppIntents
import Foundation
import SwiftData

struct TransactionCaptureIntentDependency: @unchecked Sendable {
    private let container: ModelContainer
    private let defaults: UserDefaults

    init(container: ModelContainer, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
    }

    func record(_ rawText: String) async throws -> TransactionCaptureCommitResult {
        try await MainActor.run {
            let service = TransactionCaptureService(container: container, defaults: defaults)
            let capture = try service.prepare(rawText)
            return try service.commit(capture)
        }
    }

    func recordReady(_ rawText: String) async throws -> TransactionCaptureCommitResult {
        try await MainActor.run {
            let service = TransactionCaptureService(container: container, defaults: defaults)
            let capture = try service.prepare(rawText)
            guard capture.isReady else {
                throw TransactionCaptureServiceError.incompleteCapture
            }
            return try service.commit(capture)
        }
    }

    func recordQuickExpense(
        _ preset: QuickExpensePreset
    ) async throws -> TransactionCaptureCommitResult {
        try await MainActor.run {
            let service = TransactionCaptureService(container: container, defaults: defaults)
            let capture = try service.prepareQuickExpense(preset)
            guard capture.isReady else {
                throw TransactionCaptureServiceError.incompleteCapture
            }
            return try service.commit(capture)
        }
    }
}

enum TransactionCaptureIntentError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        "MonMon couldn’t record that transaction. Open the app and check your defaults."
    }
}

struct CaptureTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Transaction"
    static let description = IntentDescription(
        "Record an expense or income from one natural-language sentence."
    )
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(
        title: "Transaction",
        description: "For example: 50k lunch cash yesterday",
        requestValueDialog: "What did you spend or receive?"
    )
    var rawEntry: String

    @Dependency private var dependency: TransactionCaptureIntentDependency

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$rawEntry)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await dependency.record(rawEntry)
            switch result.disposition {
            case .transaction:
                return .result(dialog: "Saved in MonMon.")
            case .pendingReview:
                return .result(dialog: "Saved for review in MonMon. Nothing was added to totals.")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TransactionCaptureIntentError.unavailable
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension CaptureTransactionIntent {
    static var supportedModes: IntentModes { .background }
}
