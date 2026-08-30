import Foundation

struct ReminderTime: Equatable, Sendable {
    static let minutesPerDay = 24 * 60

    let minuteOfDay: Int

    init(minuteOfDay: Int) {
        self.minuteOfDay = min(max(minuteOfDay, 0), Self.minutesPerDay - 1)
    }

    var hour: Int {
        minuteOfDay / 60
    }

    var minute: Int {
        minuteOfDay % 60
    }
}

struct NotificationPreferences: Equatable, Sendable {
    static let dailyEnabledKey = "notification.dailyExpense.enabled"
    static let dailyTimeKey = "notification.dailyExpense.minuteOfDay"
    static let recurringEnabledKey = "notification.recurringDue.enabled"
    static let recurringTimeKey = "notification.recurringDue.minuteOfDay"

    static let defaultDailyTime = ReminderTime(minuteOfDay: 20 * 60)
    static let defaultRecurringTime = ReminderTime(minuteOfDay: 9 * 60)

    let isDailyExpenseEnabled: Bool
    let dailyExpenseTime: ReminderTime
    let isRecurringDueEnabled: Bool
    let recurringDueTime: ReminderTime

    init(
        isDailyExpenseEnabled: Bool,
        dailyExpenseTime: ReminderTime,
        isRecurringDueEnabled: Bool,
        recurringDueTime: ReminderTime
    ) {
        self.isDailyExpenseEnabled = isDailyExpenseEnabled
        self.dailyExpenseTime = dailyExpenseTime
        self.isRecurringDueEnabled = isRecurringDueEnabled
        self.recurringDueTime = recurringDueTime
    }

    init(defaults: UserDefaults = .standard) {
        isDailyExpenseEnabled = defaults.bool(forKey: Self.dailyEnabledKey)
        dailyExpenseTime = Self.time(
            storedForKey: Self.dailyTimeKey,
            default: Self.defaultDailyTime,
            in: defaults
        )
        isRecurringDueEnabled = defaults.bool(forKey: Self.recurringEnabledKey)
        recurringDueTime = Self.time(
            storedForKey: Self.recurringTimeKey,
            default: Self.defaultRecurringTime,
            in: defaults
        )
    }

    private static func time(
        storedForKey key: String,
        default defaultTime: ReminderTime,
        in defaults: UserDefaults
    ) -> ReminderTime {
        guard let stored = defaults.object(forKey: key) as? Int else {
            return defaultTime
        }

        return ReminderTime(minuteOfDay: stored)
    }
}
