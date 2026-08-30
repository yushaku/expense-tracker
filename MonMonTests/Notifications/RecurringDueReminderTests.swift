import Foundation
import Testing

@testable import MonMon

@Suite("Recurring due reminder planning")
struct RecurringDueReminderTests {
    private let calendar = RecurrenceSchedule.calendar

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private func preferences(
        isEnabled: Bool = true,
        time: ReminderTime = NotificationPreferences.defaultRecurringTime
    ) -> NotificationPreferences {
        NotificationPreferences(
            isDailyExpenseEnabled: false,
            dailyExpenseTime: NotificationPreferences.defaultDailyTime,
            isRecurringDueEnabled: isEnabled,
            recurringDueTime: time
        )
    }

    private func rule(
        id: UUID = UUID(),
        name: String = "Rent",
        frequency: RecurrenceFrequency = .monthly,
        interval: Int = 1,
        anchor: Date,
        endDate: Date? = nil,
        isPaused: Bool = false
    ) -> RecurringReminderRule {
        RecurringReminderRule(
            id: id,
            name: name,
            frequency: frequency,
            interval: interval,
            anchorDate: anchor,
            endDate: endDate,
            isPaused: isPaused
        )
    }

    private func plans(
        rules: [RecurringReminderRule],
        preferences: NotificationPreferences? = nil,
        isAuthorized: Bool = true,
        now: Date
    ) -> [NotificationRequestPlan] {
        NotificationPlanner.recurringDue(
            rules: rules,
            preferences: preferences ?? self.preferences(),
            isAuthorized: isAuthorized,
            now: now,
            locale: Locale(identifier: "en"),
            calendar: calendar
        )
    }

    private func fireDates(_ plans: [NotificationRequestPlan]) -> [Date] {
        plans.compactMap { plan in
            guard case .once(let date) = plan.schedule else {
                return nil
            }
            return date
        }
    }

    @Test("Disabled or unauthorized recurring reminders create no requests")
    func disabledOrUnauthorizedCreatesNoRequests() throws {
        let rule = rule(anchor: try date(2026, 8, 30))
        let now = try date(2026, 8, 30, 8)

        #expect(plans(rules: [rule], preferences: preferences(isEnabled: false), now: now).isEmpty)
        #expect(plans(rules: [rule], isAuthorized: false, now: now).isEmpty)
    }

    @Test("Today's occurrence is kept before its time and skipped after it")
    func todayDependsOnConfiguredTime() throws {
        let rule = rule(anchor: try date(2026, 8, 30))

        let before = plans(rules: [rule], now: try date(2026, 8, 30, 8))
        let after = plans(rules: [rule], now: try date(2026, 8, 30, 10))
        let todayFireDate = try date(2026, 8, 30, 9)
        let nextFireDate = try date(2026, 9, 30, 9)

        #expect(fireDates(before).first == todayFireDate)
        #expect(fireDates(after).first == nextFireDate)
    }

    @Test("Month-end clamping, intervals, and an inclusive end date are preserved")
    func scheduleRulesArePreserved() throws {
        let monthly = rule(
            anchor: try date(2026, 1, 31),
            endDate: try date(2026, 4, 30)
        )
        let everyTwoMonths = rule(
            frequency: .monthly,
            interval: 2,
            anchor: try date(2026, 1, 31),
            endDate: try date(2026, 5, 31)
        )
        let now = try date(2026, 2, 1)

        #expect(
            fireDates(plans(rules: [monthly], now: now)) == [
                try date(2026, 2, 28, 9),
                try date(2026, 3, 31, 9),
                try date(2026, 4, 30, 9),
            ]
        )
        #expect(
            fireDates(plans(rules: [everyTwoMonths], now: now)) == [
                try date(2026, 3, 31, 9),
                try date(2026, 5, 31, 9),
            ]
        )
    }

    @Test("Paused and expired rules create no requests")
    func pausedAndExpiredCreateNoRequests() throws {
        let now = try date(2026, 8, 30, 8)
        let paused = rule(anchor: try date(2026, 8, 30), isPaused: true)
        let expired = rule(
            anchor: try date(2026, 7, 30),
            endDate: try date(2026, 8, 29)
        )

        #expect(plans(rules: [paused, expired], now: now).isEmpty)
    }

    @Test("Only the nearest sixty occurrences survive global ordering")
    func outputIsGloballyBounded() throws {
        let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let rules = [
            rule(id: laterID, name: "Later", frequency: .daily, anchor: try date(2026, 8, 31)),
            rule(id: earlierID, name: "Earlier", frequency: .daily, anchor: try date(2026, 8, 30)),
        ]

        let plans = plans(rules: rules, now: try date(2026, 8, 30, 8))
        let dates = fireDates(plans)
        let firstFireDate = try date(2026, 8, 30, 9)

        #expect(plans.count == NotificationPlanner.maxPendingRecurringRequests)
        #expect(dates == dates.sorted())
        #expect(dates.first == firstFireDate)
    }

    @Test("Identifiers are stable and content contains only the rule name")
    func identifiersAndContentArePrivacySafe() throws {
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000123"))
        let dueDate = try date(2026, 8, 30)

        let plan = try #require(
            plans(
                rules: [rule(id: id, name: "  Rent  ", anchor: dueDate)],
                now: try date(2026, 8, 30, 8)
            ).first
        )

        #expect(
            plan.identifier
                == "\(NotificationIdentifier.recurringPrefix)\(id.uuidString).\(Int(dueDate.timeIntervalSince1970))"
        )
        #expect(plan.content.title == "Recurring item due")
        #expect(plan.content.body == "Rent is due today.")
        #expect(!plan.content.body.contains("8.000.000"))
        #expect(!plan.content.body.contains("VND"))
    }
}
