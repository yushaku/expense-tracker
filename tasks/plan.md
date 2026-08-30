# Implementation Plan: Notification Reminders

## Overview

Add two opt-in local reminder types to MonMon: an unconditional daily expense-entry reminder and one privacy-safe reminder for each recurring item due that day. Both are configured in Settings, scheduled without a server, and reconciled whenever their inputs change or the app becomes active.

Approved capability map: `CAPABILITY-MAP-notification-reminders.md`.

## Architecture Decisions

- Persist two enabled flags and two minute-of-day integers in device-local `UserDefaults`. Defaults are off, 20:00 daily, and 09:00 recurring.
- Keep schedule calculation in pure `Sendable` value types. They take preferences, locale, calendar, current time, and recurring rule values explicitly; they never read SwiftData or `UNUserNotificationCenter`.
- Put authorization and pending-request side effects in one `@MainActor @Observable` coordinator owned by `MonMonApp` with `@State` and injected through the SwiftUI environment.
- Hide `UNUserNotificationCenter` behind a narrow client so coordinator decisions are testable with an in-memory fake under Swift 6 strict concurrency.
- Use one stable repeating calendar request for the daily reminder. Its hour follows the device's local time zone.
- Use one-shot requests for recurring occurrences because MonMon's arbitrary intervals, inclusive end dates, and month-end clamping cannot be represented faithfully by one repeating system trigger.
- Use MonMon's existing `Asia/Ho_Chi_Minh` financial calendar for recurring due dates and keep only the nearest 60 recurring occurrences.
- Namespace identifiers as MonMon daily or MonMon recurring. Reconciliation removes only stale identifiers in its own namespace and preserves other app requests.
- Resolve notification title/body with `AppText` and the stored `AppLanguage` at reconciliation time. A language change therefore rebuilds pending content.
- Request `.alert` and `.sound` only after an owner enables a reminder. A denied/revoked status disables ineffective reminder controls and exposes a native route to iOS Settings.

## Dependency Graph

```text
Preferences + pure plans
        │
        ├── Daily planner
        └── Recurring planner ── existing RecurrenceSchedule
                    │
Notification-center client + coordinator
                    │
          App lifecycle ownership
                    │
        Settings UI + recurring editor refresh
```

## Task List

### Phase 1: Deterministic notification domain

- [x] Task 1: Implement preferences and pure daily/recurring plans with RED/GREEN tests.

### Checkpoint: Domain

- [x] Focused notification planning tests pass on macOS.
- [x] No framework or persistence side effects exist in plan tests.

### Phase 2: System scheduling boundary

- [x] Task 2: Implement and test authorization plus scoped request reconciliation.
- [x] Task 3: Own the coordinator at app scope and reconcile on launch/active transitions.

### Checkpoint: Scheduling

- [x] Coordinator tests pass with an in-memory client.
- [x] App compiles for iOS under Swift 6 strict concurrency.
- [x] Launch does not request notification permission.

### Phase 3: User configuration and rule changes

- [x] Task 4: Add the accessible Settings card, permission feedback, time controls, and localization.
- [x] Task 5: Refresh recurring requests immediately after successful rule save or deletion.

### Checkpoint: Complete

- [x] Format lint passes.
- [x] Full macOS test suite passes.
- [x] iOS compile check passes.
- [x] SwiftUI correctness checklist and code review find no blocking issue.
- [x] The feature branch is committed and ready for user review; it is not merged or installed.

## Verification Commands

- Format: `rtk xcrun swift-format lint -r MonMon MonMonTests`
- Notification tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:MonMonTests/NotificationPreferencesTests -only-testing:MonMonTests/DailyExpenseReminderTests -only-testing:MonMonTests/RecurringDueReminderTests -only-testing:MonMonTests/NotificationCoordinatorTests test`
- Full tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- iOS compile: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Swift 6 rejects framework callback isolation or non-Sendable values. | High | Keep the observable coordinator main-actor isolated, translate framework objects at the client boundary, and run the iOS compile gate after Task 2. |
| A calendar/time-zone conversion schedules the wrong recurring day. | High | Reuse the existing recurrence calendar, plan from deterministic dates, and test today-before-time, today-after-time, month-end, interval, and end-date cases. |
| Permission is revoked outside MonMon. | Medium | Refresh system authorization whenever the app becomes active and reconcile/remove ineffective requests. |
| Editing rules leaves obsolete requests pending. | High | Use stable namespaced identifiers and replace the recurring namespace after save, delete, launch, active transition, or settings change. |
| Many recurring occurrences crowd the system queue. | Medium | Sort globally and keep only the nearest 60 one-shot recurring requests plus the single repeating daily request. |
| Notification text uses the previous app language. | Low | Resolve content from stored language every reconciliation and trigger reconciliation when language changes. |

## Open Questions

None. Capability boundaries and user-visible defaults are approved.
