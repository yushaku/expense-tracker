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

    func presentation(for capture: ParsedTransactionCapture) async throws
        -> TransactionCaptureIntentPresentation
    {
        try await MainActor.run {
            let context = ModelContext(container)
            let accounts = try context.fetch(FetchDescriptor<CashAccount>())
            let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
            let locale = AppLanguage.stored.locale

            return TransactionCaptureIntentPresentation(
                amount: capture.amount.map(VNDCurrency.format) ?? "Unknown amount",
                kind: capture.kind.displayName(in: locale),
                account: accounts.first { $0.id == capture.accountID }?.name ?? "Unknown account",
                category: categories.first { $0.id == capture.categoryID }?.name
                    ?? "Unknown category",
                date: capture.occurredAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
                )
            )
        }
    }
}

struct TransactionCaptureIntentPresentation: Equatable, Sendable {
    let amount: String
    let kind: String
    let account: String
    let category: String
    let date: String
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
            let capture = try await dependency.prepare(rawEntry)
            let presentation = try await dependency.presentation(for: capture)

            if capture.isReady {
                let confirmationDialog: IntentDialog =
                    """
                    Add \(presentation.kind) \(presentation.amount) to \(presentation.category), \
                    from \(presentation.account), on \(presentation.date)?
                    """
                try await requestConfirmation(
                    actionName: .add,
                    dialog: confirmationDialog
                )
            } else {
                try await requestConfirmation(
                    actionName: .add,
                    dialog: "Some details are unclear. Save “\(capture.rawText)” for review?"
                )
            }

            let result = try await dependency.commit(capture)
            switch result.disposition {
            case .transaction:
                return .result(dialog: "Saved \(presentation.amount) in MonMon.")
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
