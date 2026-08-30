import Foundation
import Observation
import SwiftData

enum NotificationCoordinatorFailure: Equatable, Sendable {
    case authorization
    case dataLoading
    case scheduling
}

@MainActor
@Observable
final class NotificationCoordinator {
    private let client: any NotificationCenterClient

    private(set) var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    private(set) var failure: NotificationCoordinatorFailure?

    init(client: any NotificationCenterClient) {
        self.client = client
    }

    convenience init() {
        self.init(client: SystemNotificationCenterClient())
    }

    @discardableResult
    func refreshAuthorization() async -> NotificationAuthorizationStatus {
        let status = await client.currentAuthorizationStatus()
        authorizationStatus = status
        return status
    }

    func authorizeIfNeeded() async -> Bool {
        failure = nil

        switch await refreshAuthorization() {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let isAuthorized = try await client.requestAuthorization()
                authorizationStatus = isAuthorized ? .authorized : .denied
                return isAuthorized
            } catch {
                failure = .authorization
                authorizationStatus = await client.currentAuthorizationStatus()
                return false
            }
        }
    }

    func reconcile(
        preferences: NotificationPreferences,
        recurringRules: [RecurringReminderRule],
        now: Date = .now,
        locale: Locale
    ) async {
        failure = nil
        let status = await refreshAuthorization()
        let pendingIdentifiers = await client.pendingRequestIdentifiers()
        let ownedIdentifiers = pendingIdentifiers.filter(NotificationIdentifier.isOwned)

        if !ownedIdentifiers.isEmpty {
            client.removePendingRequests(withIdentifiers: ownedIdentifiers)
        }

        let isAuthorized = status == .authorized
        let plans =
            NotificationPlanner.dailyExpense(
                preferences: preferences,
                isAuthorized: isAuthorized,
                locale: locale
            )
            + NotificationPlanner.recurringDue(
                rules: recurringRules,
                preferences: preferences,
                isAuthorized: isAuthorized,
                now: now,
                locale: locale
            )

        for plan in plans {
            do {
                try await client.add(plan)
            } catch {
                failure = .scheduling
            }
        }
    }

    func reconcile(
        in modelContext: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = .now,
        locale: Locale = AppLanguage.stored.locale
    ) async {
        let rules: [RecurringRule]
        do {
            rules = try modelContext.fetch(FetchDescriptor<RecurringRule>())
        } catch {
            failure = .dataLoading
            return
        }

        await reconcile(
            preferences: NotificationPreferences(defaults: defaults),
            recurringRules: rules.map(RecurringReminderRule.init),
            now: now,
            locale: locale
        )
    }
}

extension RecurringReminderRule {
    init(_ rule: RecurringRule) {
        self.init(
            id: rule.id,
            name: rule.note,
            frequency: rule.frequency,
            interval: rule.interval,
            anchorDate: rule.anchorDate,
            endDate: rule.endDate,
            isPaused: rule.isPaused
        )
    }
}
