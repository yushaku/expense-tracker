# Spec: Recurring Due Reminders

Module id: `recurring-due-reminders`

## Objective

When enabled, notify the owner for each active recurring rule on its due date at the configured time. Paused rules and occurrences beyond a rule's inclusive end date produce no reminder.

Default time: 09:00. Each notification identifies the rule by its name/note but excludes amount, account, category, and currency to reduce lock-screen disclosure.

## Tech Stack

- Swift 6, SwiftData recurring rules, existing `RecurrenceSchedule`, and Apple's `UserNotifications` framework on iOS 18.
- One-shot `UNCalendarNotificationTrigger` requests for a rolling set of at most 60 nearest due occurrences, rather than trying to encode MonMon's interval and month-clamping rules as repeating system triggers.
- Stable identifiers derived from reminder kind, rule UUID, and due date, allowing precise replacement and cancellation.
- Pending requests are inspected and replaced with the async APIs Apple exposes on [`UNUserNotificationCenter`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getpendingnotificationrequests%28completionhandler%3A%29).

## Commands

- Format: `rtk xcrun swift-format lint -r MonMon MonMonTests`
- Focused tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:MonMonTests/RecurringDueReminderTests test`
- Full tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- iOS compile: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- Physical-device install after user-approved merge into `dev`: `rtk scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/Notifications/` — recurring occurrence planner, privacy-safe content, and request reconciliation.
- `MonMon/Recurring/RecurringEditorView.swift` — refresh scheduling after a successful save, pause change, or deletion.
- `MonMon/App/MonMonApp.swift` — refresh after launch/active-scene reconciliation and recurring generation.
- `MonMonTests/Notifications/` — deterministic occurrence, ordering, identifier, privacy, and limit tests.
- `MonMon/Resources/Localizable.xcstrings` — recurring notification title/body.

## Code Style

Represent planned requests as plain values and sort globally before scheduling:

```swift
let plans = rules
    .flatMap { planner.plans(for: $0, after: now) }
    .sorted { $0.fireDate < $1.fireDate }
    .prefix(maxPendingRecurringRequests)
```

The planner reuses MonMon's recurrence math and takes `now`, calendar, locale, preferences, and rules as inputs. It never reads SwiftData or `UNUserNotificationCenter` directly.

## Testing Strategy

- RED/GREEN tests cover daily, weekly, monthly, yearly, interval, month-end clamping, inclusive end date, paused rules, and occurrences whose configured time has already passed today.
- Tests prove deterministic global ordering, stable unique identifiers, a maximum of 60 pending recurring requests, and one notification per rule occurrence.
- Privacy tests prove amount, currency, account, and category never enter planned content.
- Integration tests verify reconciliation removes stale recurring identifiers while leaving the daily identifier untouched.
- Compile for iOS after unit tests; the owner validates delivery and presentation on the physical iPhone only after merge into `dev`.

## Boundaries

- Always: schedule only active rules; respect interval, anchor, and end date; use MonMon's `Asia/Ho_Chi_Minh` financial calendar for due dates; preserve unrelated pending notifications; refresh after rule changes and whenever the app becomes active.
- Ask first: aggregate several due rules into one alert, expose amounts, notify before the due date, add per-rule notification switches, or sync reminder preferences.
- Never: use `lastGeneratedAt` to decide whether a due reminder exists, because transaction generation and reminder delivery are separate concerns; schedule paused/expired rules; remove the daily reminder while reconciling recurring requests.

## Success Criteria

- Each eligible recurring occurrence receives one privacy-safe notification at the configured time on its MonMon due date.
- A rule edit, pause, deletion, language change, time change, launch, or active-scene transition removes stale recurring requests and builds the current nearest set.
- Disabled or unauthorized recurring reminders leave no MonMon recurring requests pending.
- Request planning is deterministic, keeps only the nearest 60 recurring occurrences, and preserves the daily reminder and non-MonMon requests.
- No SwiftData schema change, push server, background task, or new dependency is introduced.

## Open Questions

None. The owner approved one notification per recurring item, name only, on 2026-08-30.
