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

    func notificationAccounts() async throws -> [NotificationAccountEntity] {
        try await MainActor.run {
            let context = ModelContext(container)
            return try context.fetch(FetchDescriptor<CashAccount>(sortBy: [SortDescriptor(\.name)]))
                .map { NotificationAccountEntity(id: $0.id, name: $0.name) }
        }
    }

    func recordNotification(
        _ event: BankNotificationEvent, accountID: UUID?
    ) async throws -> String {
        try await MainActor.run {
            do {
                let service = TransactionCaptureService(container: container, defaults: defaults)
                let outcome = try service.recordNotification(event, accountID: accountID)
                let result =
                    outcome.duplicate
                    ? "duplicate"
                    : outcome.result.disposition == .transaction ? "saved" : "review"
                defaults.set(result, forKey: BankNotificationPreferences.lastResultKey)
                defaults.set(
                    Date.now.timeIntervalSince1970,
                    forKey: BankNotificationPreferences.lastReceivedKey)
                return result
            } catch {
                defaults.set("failed", forKey: BankNotificationPreferences.lastResultKey)
                defaults.set(
                    Date.now.timeIntervalSince1970,
                    forKey: BankNotificationPreferences.lastReceivedKey)
                throw error
            }
        }
    }

    func recordApplePay(_ event: ApplePayEvent, accountID: UUID?) async throws -> String {
        try await MainActor.run {
            do {
                let service = TransactionCaptureService(container: container, defaults: defaults)
                let outcome = try service.recordApplePay(event, accountID: accountID)
                let result =
                    outcome.duplicate
                    ? "duplicate"
                    : outcome.result.disposition == .transaction ? "saved" : "review"
                defaults.set(result, forKey: ApplePayPreferences.lastResultKey)
                defaults.set(
                    Date.now.timeIntervalSince1970, forKey: ApplePayPreferences.lastReceivedKey)
                return result
            } catch {
                defaults.set("failed", forKey: ApplePayPreferences.lastResultKey)
                defaults.set(
                    Date.now.timeIntervalSince1970, forKey: ApplePayPreferences.lastReceivedKey)
                throw error
            }
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

struct NotificationAccountEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
    static let defaultQuery = NotificationAccountQuery()
    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct NotificationAccountQuery: EntityQuery {
    @Dependency private var dependency: TransactionCaptureIntentDependency

    func entities(for identifiers: [UUID]) async throws -> [NotificationAccountEntity] {
        try await dependency.notificationAccounts().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [NotificationAccountEntity] {
        try await dependency.notificationAccounts()
    }
}

struct CaptureBankNotificationIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Bank Notification"
    static let description = IntentDescription(
        "Receive bank notification text from Shortcuts. Choose the bank app in your automation."
    )
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Notification text") var notificationText: String
    @Parameter(title: "Source app") var sourceApp: String
    @Parameter(
        title: "Received at",
        description: "Use the original notification date. Keep the same date when retrying."
    ) var receivedAt: Date
    @Parameter(title: "Account") var account: NotificationAccountEntity?

    @Dependency private var dependency: TransactionCaptureIntentDependency

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$notificationText) from \(\.$sourceApp) at \(\.$receivedAt)") {
            \.$account
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await dependency.recordNotification(
                BankNotificationEvent(
                    text: notificationText, source: sourceApp, receivedAt: receivedAt),
                accountID: account?.id
            )
            switch result {
            case "duplicate": return .result(dialog: "This notification was already received.")
            case "saved": return .result(dialog: "Saved in MonMon.")
            default:
                return .result(dialog: "Saved for review in MonMon. Nothing was added to totals.")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw BankNotificationIntentError.unavailable
        }
    }
}

enum BankNotificationIntentError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        String(
            localized:
                "Couldn’t save the notification. Check its text and account in Bank notifications.")
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension CaptureBankNotificationIntent {
    static var supportedModes: IntentModes { .background }
}
