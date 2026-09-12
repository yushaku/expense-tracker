import Foundation
import Observation

@MainActor
@Observable
final class AppRoute {
    private(set) var quickCaptureRequestID: UUID?
    private(set) var expensesRequestID: UUID?
    private var hasQueuedQuickCapture = false

    func requestQuickCapture(isLocked: Bool) {
        if isLocked {
            hasQueuedQuickCapture = true
        } else {
            quickCaptureRequestID = UUID()
        }
    }

    @discardableResult
    func receive(_ url: URL, isLocked: Bool) -> Bool {
        if url.host == "expenses" {
            expensesRequestID = UUID()
            return true
        }
        guard Self.isQuickCaptureURL(url) else {
            return false
        }

        requestQuickCapture(isLocked: isLocked)
        return true
    }

    func releaseQueuedQuickCapture(isLocked: Bool) {
        guard hasQueuedQuickCapture, !isLocked else {
            return
        }

        hasQueuedQuickCapture = false
        quickCaptureRequestID = UUID()
    }

    func consumeExpenses() {
        expensesRequestID = nil
    }

    func consumeQuickCapture() {
        quickCaptureRequestID = nil
    }

    /// The URL that opens this build's own quick capture. Built from the
    /// flavour's registered scheme so the dev control opens the dev app, and
    /// read from the caller's Info.plist because an extension cannot read the
    /// app's. A target that wants this key must declare it.
    nonisolated static func quickCaptureURL(in infoDictionary: [String: Any]) -> URL? {
        guard
            let scheme = infoDictionary[urlSchemeInfoKey] as? String,
            !scheme.isEmpty
        else {
            return nil
        }
        return URL(string: "\(scheme)://quick-capture")
    }

    private nonisolated static let urlSchemeInfoKey = "MonMonQuickCaptureURLScheme"

    private static func isQuickCaptureURL(_ url: URL) -> Bool {
        url.host == "quick-capture"
            || url.pathComponents.contains("quick-capture")
    }
}
