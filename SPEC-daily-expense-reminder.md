# Spec: Daily Expense Reminder

Module id: `daily-expense-reminder`

## Objective

When enabled, remind the owner every day at the configured time to record the day's spending. The reminder is intentionally unconditional: it does not inspect whether an expense has already been entered, so the system can deliver it without MonMon running in the background.

Default time: 20:00. The notification contains no amount, account, category, or transaction data.

## Tech Stack

- Swift 6 and Apple's `UserNotifications` framework on iOS 18.
- One stable `UNNotificationRequest` identifier and a repeating `UNCalendarNotificationTrigger` containing hour and minute components.
- Alert and default sound only; no badge.
- Calendar-trigger scheduling follows [Apple's local-notification pattern](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

## Commands

- Format: `rtk xcrun swift-format lint -r MonMon MonMonTests`
- Focused tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:MonMonTests/DailyExpenseReminderTests test`
- Full tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- iOS compile: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- Physical-device install after user-approved merge into `dev`: `rtk scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/Notifications/` — daily request planning and notification-center scheduling.
- `MonMonTests/Notifications/` — deterministic request-plan tests.
- `MonMon/Resources/Localizable.xcstrings` — notification title and body in supported languages.

## Code Style

Build a deterministic request plan before crossing the framework boundary:

```swift
let plan = DailyReminderPlan(
    identifier: NotificationIdentifier.dailyExpense,
    hour: reminderTime.hour,
    minute: reminderTime.minute
)
```

Pure planning types contain no singleton reads and take locale/configuration explicitly. The `UNUserNotificationCenter` adapter only translates an approved plan into system content, trigger, and request values.

## Testing Strategy

- RED/GREEN tests prove the stable identifier, default 20:00 time, configured hour/minute, and privacy-safe content inputs.
- Test disabled and unauthorized states produce no plan.
- Do not test Apple's trigger implementation; test MonMon's inputs and decisions.
- Compile for iOS after unit tests because `UserNotifications` integration is iOS-only.
- The owner validates actual delivery time and localized presentation on the physical iPhone after merge into `dev`.

## Boundaries

- Always: use a repeating local calendar trigger; follow the device's current local time zone; replace the previous daily request when time or language changes; remove it when disabled.
- Ask first: suppress reminders after an expense entry, add weekday selection, customize sound, or include financial content.
- Never: depend on background execution, create more than one pending daily reminder, display a badge, or imply that the reminder means no expense was recorded.

## Success Criteria

- With permission and the setting enabled, exactly one repeating daily request exists at the selected local hour and minute.
- Changing the time replaces that request without leaving the old one pending.
- Disabling the setting removes it.
- The title/body are localized using MonMon's selected language and contain no financial details.
- The reminder continues to be system-scheduled while MonMon is not running, subject to iOS delivery behavior.

## Open Questions

None. The owner approved an unconditional daily reminder on 2026-08-30.
