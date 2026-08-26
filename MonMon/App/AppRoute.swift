import Foundation
import Observation

@MainActor
@Observable
final class AppRoute {
    private(set) var quickCaptureRequestID: UUID?
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

    func consumeQuickCapture() {
        quickCaptureRequestID = nil
    }

    private static func isQuickCaptureURL(_ url: URL) -> Bool {
        url.host == "quick-capture"
            || url.pathComponents.contains("quick-capture")
    }
}
