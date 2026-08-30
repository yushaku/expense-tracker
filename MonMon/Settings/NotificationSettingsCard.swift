import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct NotificationSettingsCard: View {
    @Environment(NotificationCoordinator.self) private var coordinator
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @AppStorage(NotificationPreferences.dailyEnabledKey) private var isDailyEnabled = false
    @AppStorage(NotificationPreferences.dailyTimeKey) private var dailyMinuteOfDay =
        NotificationPreferences.defaultDailyTime.minuteOfDay
    @AppStorage(NotificationPreferences.recurringEnabledKey) private var isRecurringEnabled = false
    @AppStorage(NotificationPreferences.recurringTimeKey) private var recurringMinuteOfDay =
        NotificationPreferences.defaultRecurringTime.minuteOfDay

    @State private var isUpdating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Notifications", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundStyle(MonMonTheme.textPrimary)

            reminderControl(
                title: "Daily expense reminder",
                explanation: "Reminds you every day even if you already recorded spending.",
                isEnabled: dailyBinding,
                minuteOfDay: $dailyMinuteOfDay,
                toggleIdentifier: "daily-expense-reminder",
                timeIdentifier: "daily-expense-reminder-time"
            )

            Divider()
                .overlay(MonMonTheme.border)

            reminderControl(
                title: "Recurring due reminders",
                explanation: "Notifies you for each active recurring item due that day.",
                isEnabled: recurringBinding,
                minuteOfDay: $recurringMinuteOfDay,
                toggleIdentifier: "recurring-due-reminders",
                timeIdentifier: "recurring-due-reminders-time"
            )

            if coordinator.authorizationStatus == .denied {
                permissionMessage
            }

            if coordinator.failure != nil {
                Label(
                    "Couldn’t update notification reminders. Try again.",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.danger)
                .accessibilityIdentifier("notification-reminder-error")
            }
        }
        .task {
            let status = await coordinator.refreshAuthorization()
            guard status == .denied, isDailyEnabled || isRecurringEnabled else {
                return
            }

            isDailyEnabled = false
            isRecurringEnabled = false
            await coordinator.reconcile(in: modelContext, locale: locale)
        }
        .onChange(of: dailyMinuteOfDay) { _, _ in
            reconcile()
        }
        .onChange(of: recurringMinuteOfDay) { _, _ in
            reconcile()
        }
    }

    private func reminderControl(
        title: LocalizedStringKey,
        explanation: LocalizedStringKey,
        isEnabled: Binding<Bool>,
        minuteOfDay: Binding<Int>,
        toggleIdentifier: String,
        timeIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isEnabled) {
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)
            .tint(MonMonTheme.accent)
            .disabled(isUpdating || coordinator.authorizationStatus == .denied)
            .accessibilityIdentifier(toggleIdentifier)

            Text(explanation)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            if isEnabled.wrappedValue {
                DatePicker(
                    "Reminder time",
                    selection: timeBinding(minuteOfDay),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .font(.subheadline)
                .accessibilityIdentifier(timeIdentifier)
            }
        }
    }

    private var dailyBinding: Binding<Bool> {
        Binding(
            get: { isDailyEnabled },
            set: { newValue in
                isDailyEnabled = newValue
                updateAuthorizationAndSchedules(enabled: newValue) {
                    isDailyEnabled = false
                }
            }
        )
    }

    private var recurringBinding: Binding<Bool> {
        Binding(
            get: { isRecurringEnabled },
            set: { newValue in
                isRecurringEnabled = newValue
                updateAuthorizationAndSchedules(enabled: newValue) {
                    isRecurringEnabled = false
                }
            }
        )
    }

    private var permissionMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "Notifications are turned off in iPhone Settings.",
                systemImage: "bell.slash.fill"
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)

            #if os(iOS)
                Button("Open iPhone Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    openURL(url)
                }
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("open-notification-settings")
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notification-permission-denied")
    }

    private func timeBinding(_ minuteOfDay: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let time = ReminderTime(minuteOfDay: minuteOfDay.wrappedValue)
                let calendar = Calendar.autoupdatingCurrent
                return calendar.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.autoupdatingCurrent.dateComponents(
                    [.hour, .minute],
                    from: date
                )
                minuteOfDay.wrappedValue =
                    (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }

    private func updateAuthorizationAndSchedules(
        enabled: Bool,
        rollback: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            isUpdating = true
            defer { isUpdating = false }

            if enabled, !(await coordinator.authorizeIfNeeded()) {
                rollback()
            }

            await coordinator.reconcile(in: modelContext, locale: locale)
        }
    }

    private func reconcile() {
        Task { @MainActor in
            await coordinator.reconcile(in: modelContext, locale: locale)
        }
    }
}
