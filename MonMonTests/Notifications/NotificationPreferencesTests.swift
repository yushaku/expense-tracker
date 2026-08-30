import Foundation
import Testing

@testable import MonMon

@Suite("Notification preferences")
struct NotificationPreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "monmon.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test("Reminders default off at the agreed times")
    func defaultsAreDisabled() {
        let preferences = NotificationPreferences(defaults: makeDefaults())

        #expect(!preferences.isDailyExpenseEnabled)
        #expect(preferences.dailyExpenseTime == ReminderTime(minuteOfDay: 20 * 60))
        #expect(!preferences.isRecurringDueEnabled)
        #expect(preferences.recurringDueTime == ReminderTime(minuteOfDay: 9 * 60))
    }

    @Test("Stored values are loaded through the public keys")
    func storedValuesAreLoaded() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: NotificationPreferences.dailyEnabledKey)
        defaults.set(7 * 60 + 15, forKey: NotificationPreferences.dailyTimeKey)
        defaults.set(true, forKey: NotificationPreferences.recurringEnabledKey)
        defaults.set(18 * 60 + 45, forKey: NotificationPreferences.recurringTimeKey)

        let preferences = NotificationPreferences(defaults: defaults)

        #expect(preferences.isDailyExpenseEnabled)
        #expect(preferences.dailyExpenseTime == ReminderTime(minuteOfDay: 7 * 60 + 15))
        #expect(preferences.isRecurringDueEnabled)
        #expect(preferences.recurringDueTime == ReminderTime(minuteOfDay: 18 * 60 + 45))
    }

    @Test("A reminder time stays inside one day")
    func reminderTimeClampsToOneDay() {
        #expect(ReminderTime(minuteOfDay: -1).minuteOfDay == 0)
        #expect(ReminderTime(minuteOfDay: 24 * 60).minuteOfDay == 24 * 60 - 1)
    }
}
