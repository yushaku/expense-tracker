import Foundation

enum NotificationIdentifier {
    static let dailyExpense = "monmon.notification.daily-expense"
    static let recurringPrefix = "monmon.notification.recurring."

    static func isOwned(_ identifier: String) -> Bool {
        identifier == dailyExpense || identifier.hasPrefix(recurringPrefix)
    }
}

struct NotificationContentPlan: Equatable, Sendable {
    let title: String
    let body: String
}

enum NotificationSchedule: Equatable, Sendable {
    case daily(ReminderTime)
    case once(Date)
}

struct NotificationRequestPlan: Equatable, Sendable {
    let identifier: String
    let content: NotificationContentPlan
    let schedule: NotificationSchedule
}

struct RecurringReminderRule: Equatable, Sendable {
    let id: UUID
    let name: String
    let frequency: RecurrenceFrequency
    let interval: Int
    let anchorDate: Date
    let endDate: Date?
    let isPaused: Bool
}

enum NotificationPlanner {
    static let maxPendingRecurringRequests = 60

    static func dailyExpense(
        preferences: NotificationPreferences,
        isAuthorized: Bool,
        locale: Locale
    ) -> [NotificationRequestPlan] {
        guard preferences.isDailyExpenseEnabled, isAuthorized else {
            return []
        }

        return [
            NotificationRequestPlan(
                identifier: NotificationIdentifier.dailyExpense,
                content: NotificationContentPlan(
                    title: AppText.string("Daily spending reminder", in: locale),
                    body: AppText.string(
                        "Take a moment to record today's spending.",
                        in: locale
                    )
                ),
                schedule: .daily(preferences.dailyExpenseTime)
            )
        ]
    }

    static func recurringDue(
        rules: [RecurringReminderRule],
        preferences: NotificationPreferences,
        isAuthorized: Bool,
        now: Date,
        locale: Locale,
        calendar: Calendar = RecurrenceSchedule.calendar
    ) -> [NotificationRequestPlan] {
        guard preferences.isRecurringDueEnabled, isAuthorized else {
            return []
        }

        return
            rules
            .flatMap {
                recurringPlans(
                    for: $0,
                    time: preferences.recurringDueTime,
                    now: now,
                    locale: locale,
                    calendar: calendar
                )
            }
            .sorted(by: recurringPlanComesFirst)
            .prefix(maxPendingRecurringRequests)
            .map { $0 }
    }

    private static func recurringPlans(
        for rule: RecurringReminderRule,
        time: ReminderTime,
        now: Date,
        locale: Locale,
        calendar: Calendar
    ) -> [NotificationRequestPlan] {
        guard !rule.isPaused, rule.interval >= 1 else {
            return []
        }

        let today = calendar.startOfDay(for: now)
        guard let dayBeforeToday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return []
        }

        let todayOccurrence = RecurrenceSchedule.occurrences(
            frequency: rule.frequency,
            interval: rule.interval,
            anchor: rule.anchorDate,
            after: dayBeforeToday,
            through: today,
            limit: 1
        ).first
        var nextDueDate =
            todayOccurrence
            ?? RecurrenceSchedule.nextOccurrence(
                frequency: rule.frequency,
                interval: rule.interval,
                anchor: rule.anchorDate,
                after: today
            )
        var plans: [NotificationRequestPlan] = []

        while let dueDate = nextDueDate, plans.count < maxPendingRecurringRequests {
            let dueDay = calendar.startOfDay(for: dueDate)
            if let endDate = rule.endDate,
                dueDay > calendar.startOfDay(for: endDate)
            {
                break
            }

            if let fireDate = fireDate(on: dueDay, at: time, calendar: calendar), fireDate > now {
                plans.append(
                    NotificationRequestPlan(
                        identifier: recurringIdentifier(ruleID: rule.id, dueDate: dueDay),
                        content: recurringContent(name: rule.name, locale: locale),
                        schedule: .once(fireDate)
                    )
                )
            }

            nextDueDate = RecurrenceSchedule.nextOccurrence(
                frequency: rule.frequency,
                interval: rule.interval,
                anchor: rule.anchorDate,
                after: dueDay
            )
        }

        return plans
    }

    private static func fireDate(
        on dueDate: Date,
        at time: ReminderTime,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: dueDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private static func recurringIdentifier(ruleID: UUID, dueDate: Date) -> String {
        "\(NotificationIdentifier.recurringPrefix)\(ruleID.uuidString).\(Int(dueDate.timeIntervalSince1970))"
    }

    private static func recurringContent(name: String, locale: Locale) -> NotificationContentPlan {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let body =
            trimmedName.isEmpty
            ? AppText.string("A recurring item is due today.", in: locale)
            : AppText.string("\(trimmedName) is due today.", in: locale)

        return NotificationContentPlan(
            title: AppText.string("Recurring item due", in: locale),
            body: body
        )
    }

    private static func recurringPlanComesFirst(
        _ left: NotificationRequestPlan,
        _ right: NotificationRequestPlan
    ) -> Bool {
        guard case .once(let leftDate) = left.schedule,
            case .once(let rightDate) = right.schedule,
            leftDate == rightDate
        else {
            return fireDate(of: left) < fireDate(of: right)
        }

        return left.identifier < right.identifier
    }

    private static func fireDate(of plan: NotificationRequestPlan) -> Date {
        guard case .once(let date) = plan.schedule else {
            return .distantFuture
        }
        return date
    }
}
