import Foundation
import Observation

enum QuickCaptureLaunchMode: Equatable, Sendable {
    case keyboard
    case voice
}

struct QuickCaptureRequest: Equatable, Identifiable, Sendable {
    let id: UUID
    let mode: QuickCaptureLaunchMode

    init(id: UUID = UUID(), mode: QuickCaptureLaunchMode) {
        self.id = id
        self.mode = mode
    }
}

@MainActor
@Observable
final class AppRoute {
    private(set) var quickCaptureRequest: QuickCaptureRequest?
    private var queuedQuickCaptureMode: QuickCaptureLaunchMode?

    var quickCaptureRequestID: UUID? {
        quickCaptureRequest?.id
    }

    func requestQuickCapture(
        mode: QuickCaptureLaunchMode = .keyboard,
        isLocked: Bool
    ) {
        if isLocked {
            queuedQuickCaptureMode = mode
        } else {
            quickCaptureRequest = QuickCaptureRequest(mode: mode)
        }
    }

    @discardableResult
    func receive(_ url: URL, isLocked: Bool) -> Bool {
        guard Self.isQuickCaptureURL(url) else {
            return false
        }

        requestQuickCapture(mode: .keyboard, isLocked: isLocked)
        return true
    }

    func releaseQueuedQuickCapture(isLocked: Bool) {
        guard let mode = queuedQuickCaptureMode, !isLocked else {
            return
        }

        queuedQuickCaptureMode = nil
        quickCaptureRequest = QuickCaptureRequest(mode: mode)
    }

    func consumeQuickCapture() {
        quickCaptureRequest = nil
    }

    private static func isQuickCaptureURL(_ url: URL) -> Bool {
        url.host == "quick-capture"
            || url.pathComponents.contains("quick-capture")
    }
}
