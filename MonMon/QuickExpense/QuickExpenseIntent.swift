import AppIntents
import Foundation

extension QuickExpenseSlot: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Quick Expense Preset"
    static let caseDisplayRepresentations: [QuickExpenseSlot: DisplayRepresentation] = [
        .coffee: "Coffee",
        .lunch: "Lunch",
        .fuel: "Fuel",
        .groceries: "Groceries",
        .parking: "Parking",
        .transit: "Transit",
        .medicine: "Medicine",
        .entertainment: "Entertainment",
        .bills: "Bills",
    ]
}

struct QuickExpenseIntentDependency: Sendable {
    private let recorder: @Sendable (QuickExpenseSlot) async throws -> Void
    private let feedbackRecorder: @Sendable (QuickExpenseSlot) async -> Void

    init(
        feedbackRecorder: @escaping @Sendable (QuickExpenseSlot) async -> Void = { slot in
            QuickExpenseFeedbackStore().recordSuccess(for: slot)
        },
        _ recorder: @escaping @Sendable (QuickExpenseSlot) async throws -> Void
    ) {
        self.feedbackRecorder = feedbackRecorder
        self.recorder = recorder
    }

    func record(_ slot: QuickExpenseSlot) async throws {
        try await recorder(slot)
        await feedbackRecorder(slot)
    }
}

enum QuickExpenseIntentError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        "MonMon couldn’t save that expense. Open the app and check your defaults."
    }
}

struct RecordQuickExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Quick Expense"
    static let description = IntentDescription("Record one configured expense preset.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let isDiscoverable = false

    @Parameter(title: "Preset")
    var slot: QuickExpenseSlot

    @Dependency private var dependency: QuickExpenseIntentDependency

    init() {
        slot = .coffee
    }

    init(slot: QuickExpenseSlot) {
        self.slot = slot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Record \(\.$slot)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await dependency.record(slot)
            return .result(dialog: "Saved in MonMon.")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw QuickExpenseIntentError.unavailable
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension RecordQuickExpenseIntent {
    static var supportedModes: IntentModes { .background }
}

#if !WIDGET_EXTENSION
    // On iOS 18-25 this compatibility conformance keeps widget execution in the
    // app process. The widget target declares the intent but cannot itself adopt
    // this app-only protocol. iOS 26 uses `supportedModes` above instead.
    @available(*, deprecated)
    extension RecordQuickExpenseIntent: ForegroundContinuableIntent {}
#endif
