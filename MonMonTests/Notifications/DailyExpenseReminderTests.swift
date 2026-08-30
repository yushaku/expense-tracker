import Foundation
import Testing

@testable import MonMon

@Suite("Daily expense reminder planning")
struct DailyExpenseReminderTests {
    private func preferences(
        isEnabled: Bool,
        time: ReminderTime = NotificationPreferences.defaultDailyTime
    ) -> NotificationPreferences {
        NotificationPreferences(
            isDailyExpenseEnabled: isEnabled,
            dailyExpenseTime: time,
            isRecurringDueEnabled: false,
            recurringDueTime: NotificationPreferences.defaultRecurringTime
        )
    }

    @Test("A disabled reminder creates no request")
    func disabledCreatesNoRequest() {
        let plans = NotificationPlanner.dailyExpense(
            preferences: preferences(isEnabled: false),
            isAuthorized: true,
            locale: Locale(identifier: "en")
        )

        #expect(plans.isEmpty)
    }

    @Test("An unauthorized reminder creates no request")
    func unauthorizedCreatesNoRequest() {
        let plans = NotificationPlanner.dailyExpense(
            preferences: preferences(isEnabled: true),
            isAuthorized: false,
            locale: Locale(identifier: "en")
        )

        #expect(plans.isEmpty)
    }

    @Test("An enabled reminder creates one stable repeating request")
    func enabledCreatesOneRequest() throws {
        let time = ReminderTime(minuteOfDay: 7 * 60 + 15)

        let plans = NotificationPlanner.dailyExpense(
            preferences: preferences(isEnabled: true, time: time),
            isAuthorized: true,
            locale: Locale(identifier: "en")
        )
        let plan = try #require(plans.first)

        #expect(plans.count == 1)
        #expect(plan.identifier == NotificationIdentifier.dailyExpense)
        #expect(plan.schedule == .daily(time))
        #expect(plan.content.title == "Daily spending reminder")
        #expect(plan.content.body == "Take a moment to record today's spending.")
        #expect(!plan.content.title.contains("₫"))
        #expect(!plan.content.body.contains("₫"))
    }
}
