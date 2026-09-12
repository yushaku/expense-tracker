import AppIntents
import Foundation

enum QuickCaptureIntentError: Error, LocalizedError, Sendable {
    case schemeUnavailable

    var errorDescription: String? {
        "MonMon couldn’t open. Reinstall the app to restore its URL scheme."
    }
}

/// What the Control Center control actually runs. Opening the app is the whole
/// job: Control Center has no keyboard, so the transaction has to be typed in
/// the app.
///
/// The control cannot do this itself. A control's action runs in the widget
/// extension's process, and only an intent that asks for the foreground brings
/// the app forward — a bare `OpenURLIntent` handed to the button runs in the
/// background and nothing happens. This intent is what asks: `openAppWhenRun`
/// on iOS 18-25, `supportedModes` on iOS 26 and later.
///
/// It must belong to both the app and the widget extension target. The system
/// looks the intent up in the app to open it, and in the extension to run it.
struct OpenQuickCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Quick Capture"
    static let description = IntentDescription("Open MonMon and start a new transaction.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let isDiscoverable = false
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = AppRoute.quickCaptureURL(in: Bundle.main.infoDictionary ?? [:]) else {
            throw QuickCaptureIntentError.schemeUnavailable
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension OpenQuickCaptureIntent {
    static var supportedModes: IntentModes { .foreground }
}
