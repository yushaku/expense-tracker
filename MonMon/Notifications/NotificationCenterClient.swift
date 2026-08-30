import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

@MainActor
protocol NotificationCenterClient: AnyObject {
    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func pendingRequestIdentifiers() async -> [String]
    func add(_ plan: NotificationRequestPlan) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemNotificationCenterClient: NotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        // Source: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func add(_ plan: NotificationRequestPlan) async throws {
        let content = UNMutableNotificationContent()
        content.title = plan.content.title
        content.body = plan.content.body
        content.sound = .default

        // Source: https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
        let trigger: UNNotificationTrigger
        switch plan.schedule {
        case .daily(let time):
            trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: time.hour, minute: time.minute),
                repeats: true
            )
        case .once(let date):
            let calendar = RecurrenceSchedule.calendar
            var components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        try await center.add(
            UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
