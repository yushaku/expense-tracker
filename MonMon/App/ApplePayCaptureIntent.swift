import AppIntents
import Foundation

struct CaptureApplePayTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Apple Pay Transaction"
    static let description = IntentDescription(
        "Receive a Wallet transaction from your Shortcuts automation. Review by default; automatic saving is optional in Apple Pay settings."
    )
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(
        title: "Amount",
        description:
            "Use Shortcut Input → Amount, including its currency. Do not convert to a plain number."
    )
    var payment: IntentCurrencyAmount?
    @Parameter(title: "Merchant") var merchant: String?
    @Parameter(
        title: "Transaction date",
        description:
            "Keep the same original event date when retrying. A new date creates a new capture.")
    var occurredAt: Date
    @Parameter(title: "Card label", description: "Optional card name, not the full card number.")
    var card: String?
    @Parameter(title: "Account") var account: NotificationAccountEntity?

    @Dependency private var dependency: TransactionCaptureIntentDependency

    static var parameterSummary: some ParameterSummary {
        Summary("Record Apple Pay \(\.$payment) at \(\.$merchant) on \(\.$occurredAt)") {
            \.$account
            \.$card
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await dependency.recordApplePay(
                ApplePayEvent(
                    amount: payment?.amount, currency: payment?.currencyCode ?? "",
                    merchant: merchant ?? "", occurredAt: occurredAt, card: card ?? ""),
                accountID: account?.id)
            switch result {
            case "duplicate": return .result(dialog: "This Apple Pay event was already received.")
            case "saved": return .result(dialog: "Saved in MonMon.")
            default:
                return .result(dialog: "Saved for review in MonMon. Nothing was added to totals.")
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ApplePayCaptureIntentError.unavailable
        }
    }
}

enum ApplePayCaptureIntentError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        String(
            localized:
                "Couldn’t capture Apple Pay. Check the action’s fields and account, then retry with the original date."
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension CaptureApplePayTransactionIntent {
    static var supportedModes: IntentModes { .background }
}
