import Foundation
import Testing

@testable import MonMon

@Suite("Notification coordinator")
@MainActor
struct NotificationCoordinatorTests {
    private enum StubError: Error {
        case failed
    }

    private final class FakeNotificationCenterClient: NotificationCenterClient {
        var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
        var authorizationResult = true
        var authorizationError: Error?
        var pendingIdentifiers: [String] = []
        var pendingFingerprints: [String: String] = [:]
        var addedPlans: [NotificationRequestPlan] = []
        var removedIdentifiers: [[String]] = []
        var addError: Error?
        var authorizationRequests = 0

        func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
            authorizationStatus
        }

        func requestAuthorization() async throws -> Bool {
            authorizationRequests += 1
            if let authorizationError {
                throw authorizationError
            }
            authorizationStatus = authorizationResult ? .authorized : .denied
            return authorizationResult
        }

        func pendingRequests() async -> [PendingNotificationRequest] {
            pendingIdentifiers.map {
                PendingNotificationRequest(identifier: $0, fingerprint: pendingFingerprints[$0])
            }
        }

        func add(_ plan: NotificationRequestPlan) async throws {
            if let addError {
                throw addError
            }
            addedPlans.append(plan)
        }

        func removePendingRequests(withIdentifiers identifiers: [String]) {
            removedIdentifiers.append(identifiers)
        }
    }

    private func preferences(
        daily: Bool,
        recurring: Bool
    ) -> NotificationPreferences {
        NotificationPreferences(
            isDailyExpenseEnabled: daily,
            dailyExpenseTime: NotificationPreferences.defaultDailyTime,
            isRecurringDueEnabled: recurring,
            recurringDueTime: NotificationPreferences.defaultRecurringTime
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0
    ) throws -> Date {
        try #require(
            RecurrenceSchedule.calendar.date(
                from: DateComponents(year: year, month: month, day: day, hour: hour)
            )
        )
    }

    @Test("Undetermined authorization is requested once in context")
    func undeterminedAuthorizationIsRequested() async {
        let client = FakeNotificationCenterClient()
        let coordinator = NotificationCoordinator(client: client)

        let first = await coordinator.authorizeIfNeeded()
        let second = await coordinator.authorizeIfNeeded()

        #expect(first)
        #expect(second)
        #expect(client.authorizationRequests == 1)
        #expect(coordinator.authorizationStatus == .authorized)
        #expect(coordinator.failure == nil)
    }

    @Test("Denied authorization is not requested again")
    func deniedAuthorizationIsNotRequestedAgain() async {
        let client = FakeNotificationCenterClient()
        client.authorizationStatus = .denied
        let coordinator = NotificationCoordinator(client: client)

        let isAuthorized = await coordinator.authorizeIfNeeded()

        #expect(!isAuthorized)
        #expect(client.authorizationRequests == 0)
        #expect(coordinator.authorizationStatus == .denied)
    }

    @Test("Authorization framework errors remain actionable")
    func authorizationErrorIsSurfaced() async {
        let client = FakeNotificationCenterClient()
        client.authorizationError = StubError.failed
        let coordinator = NotificationCoordinator(client: client)

        let isAuthorized = await coordinator.authorizeIfNeeded()

        #expect(!isAuthorized)
        #expect(coordinator.authorizationStatus == .notDetermined)
        #expect(coordinator.failure == .authorization)
    }

    @Test("Reconciliation replaces only MonMon requests")
    func reconciliationIsScoped() async throws {
        let client = FakeNotificationCenterClient()
        client.authorizationStatus = .authorized
        client.pendingIdentifiers = [
            NotificationIdentifier.dailyExpense,
            "\(NotificationIdentifier.recurringPrefix)stale",
            "another-feature.request",
        ]
        let coordinator = NotificationCoordinator(client: client)
        let ruleID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000321"))
        let dueDate = try date(2026, 8, 30)
        let rule = RecurringReminderRule(
            id: ruleID,
            name: "Rent",
            frequency: .monthly,
            interval: 1,
            anchorDate: dueDate,
            endDate: dueDate,
            isPaused: false
        )

        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: true),
            recurringRules: [rule],
            now: try date(2026, 8, 30, 8),
            locale: Locale(identifier: "en")
        )

        #expect(
            Set(client.removedIdentifiers.flatMap { $0 }) == [
                NotificationIdentifier.dailyExpense,
                "\(NotificationIdentifier.recurringPrefix)stale",
            ]
        )
        #expect(!client.removedIdentifiers.flatMap { $0 }.contains("another-feature.request"))
        #expect(client.addedPlans.count == 2)
        #expect(client.addedPlans.contains { $0.identifier == NotificationIdentifier.dailyExpense })
        #expect(
            client.addedPlans.contains {
                $0.identifier.hasPrefix(NotificationIdentifier.recurringPrefix)
            })
    }

    @Test("Requests that already match their plans are left alone; changed ones are replaced")
    func unchangedRequestsAreKept() async throws {
        let client = FakeNotificationCenterClient()
        client.authorizationStatus = .authorized
        let coordinator = NotificationCoordinator(client: client)
        let now = try date(2026, 8, 30, 8)
        let english = Locale(identifier: "en")

        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: false),
            recurringRules: [], now: now, locale: english)
        let scheduled = client.addedPlans
        #expect(scheduled.count == 1)

        // The system now holds what was added, stamped with its fingerprint.
        client.pendingIdentifiers = scheduled.map(\.identifier) + ["another-feature.request"]
        client.pendingFingerprints = Dictionary(
            uniqueKeysWithValues: scheduled.map { ($0.identifier, $0.fingerprint) })
        client.addedPlans = []
        client.removedIdentifiers = []

        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: false),
            recurringRules: [], now: now, locale: english)
        #expect(client.addedPlans.isEmpty)
        #expect(client.removedIdentifiers.isEmpty)

        // A different language changes the text, so the request is replaced.
        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: false),
            recurringRules: [], now: now, locale: Locale(identifier: "vi"))
        #expect(client.removedIdentifiers == [[NotificationIdentifier.dailyExpense]])
        #expect(client.addedPlans.map(\.identifier) == [NotificationIdentifier.dailyExpense])
    }

    @Test("Revoked authorization removes owned requests and adds nothing")
    func revokedAuthorizationClearsOwnedRequests() async throws {
        let client = FakeNotificationCenterClient()
        client.authorizationStatus = .denied
        client.pendingIdentifiers = [NotificationIdentifier.dailyExpense, "unrelated"]
        let coordinator = NotificationCoordinator(client: client)

        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: true),
            recurringRules: [],
            now: try date(2026, 8, 30, 8),
            locale: Locale(identifier: "en")
        )

        #expect(client.removedIdentifiers == [[NotificationIdentifier.dailyExpense]])
        #expect(client.addedPlans.isEmpty)
        #expect(coordinator.authorizationStatus == .denied)
    }

    @Test("Framework failures are surfaced without throwing into financial work")
    func frameworkFailureIsSurfaced() async throws {
        let client = FakeNotificationCenterClient()
        client.authorizationStatus = .authorized
        client.addError = StubError.failed
        let coordinator = NotificationCoordinator(client: client)

        await coordinator.reconcile(
            preferences: preferences(daily: true, recurring: false),
            recurringRules: [],
            now: try date(2026, 8, 30, 8),
            locale: Locale(identifier: "en")
        )

        #expect(coordinator.failure == .scheduling)
    }
}
