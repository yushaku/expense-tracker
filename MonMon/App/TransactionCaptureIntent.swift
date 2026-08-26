import AppIntents
import Foundation
import SwiftData

struct TransactionCaptureIntentDependency: @unchecked Sendable {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func prepare(_ rawText: String) async throws -> ParsedTransactionCapture {
        try await MainActor.run {
            try TransactionCaptureService(container: container).prepare(rawText)
        }
    }

    func commit(
        _ capture: ParsedTransactionCapture
    ) async throws -> TransactionCaptureCommitResult {
        try await MainActor.run {
            try TransactionCaptureService(container: container).commit(capture)
        }
    }

}

enum TransactionCaptureIntentError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        "MonMon couldn’t record that transaction. Open the app and check your defaults."
    }
}

struct OpenQuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Quick Capture"
    static let description = IntentDescription("Open MonMon ready for one natural-language entry.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult & OpensIntent {
        guard
            let scheme = Bundle.main.object(forInfoDictionaryKey: "MonMonQuickCaptureURLScheme")
                as? String,
            let url = URL(string: "\(scheme)://quick-capture")
        else {
            throw TransactionCaptureIntentError.unavailable
        }

        return .result(opensIntent: OpenURLIntent(url))
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
            let capture = try await dependency.prepare(rawEntry)

            if capture.isReady {
                try await requestConfirmation(
                    actionName: .add,
                    dialog: "Save this transaction in MonMon?"
                )
            } else {
                try await requestConfirmation(
                    actionName: .add,
                    dialog: "Some details are unclear. Save it for review?"
                )
            }

            let result = try await dependency.commit(capture)
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
