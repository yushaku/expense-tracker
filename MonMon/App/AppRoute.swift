import Foundation
import Observation

@MainActor
@Observable
final class AppRoute {
    private(set) var quickCaptureRequestID: UUID?
    private(set) var goalRequestID: UUID?
    private(set) var goalRequestRevision: UUID?
    private var queuedGoalID: UUID?
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
        if url.host == "goal", let id = UUID(uuidString: url.lastPathComponent) {
            if isLocked {
                queuedGoalID = id
            } else {
                goalRequestID = id
                goalRequestRevision = UUID()
            }
            return true
        }
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
        if !isLocked, let id = queuedGoalID {
            goalRequestID = id
            goalRequestRevision = UUID()
            queuedGoalID = nil
        }
        guard hasQueuedQuickCapture, !isLocked else {
            return
        }

        hasQueuedQuickCapture = false
        quickCaptureRequestID = UUID()
    }

    func consumeGoal() { goalRequestID = nil }
    func consumeGoalTabRequest() { goalRequestRevision = nil }
    func consumeExpenses() {
        expensesRequestID = nil
    }

    func consumeQuickCapture() {
        quickCaptureRequestID = nil
    }

    private static func isQuickCaptureURL(_ url: URL) -> Bool {
        url.host == "quick-capture"
            || url.pathComponents.contains("quick-capture")
    }
}
