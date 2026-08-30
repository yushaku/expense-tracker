# Spec: Notification Settings

Module id: `notification-settings`

## Objective

Add a Notifications card to MonMon Settings where the owner can independently enable and choose a time for:

- the daily expense-entry reminder; and
- reminders for recurring items due that day.

Both options are disabled by default. Enabling the first option that needs notifications requests alert and sound authorization in context. A denied or later-revoked authorization must be shown clearly and must not leave a control looking effective when no notification can be delivered.

## Tech Stack

- Swift 6, SwiftUI, and Observation, built with Xcode 26.6.
- iOS 18 deployment target.
- Apple's `UserNotifications` framework; no server, APNs registration, background mode, or third-party dependency.
- Device-local `UserDefaults` preferences, exposed through `@AppStorage` where appropriate. Notification preferences do not enter SwiftData, CloudKit, or backups.
- Permission is requested only when the owner enables a reminder, following [Apple's contextual authorization guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications).

## Commands

- Format: `rtk xcrun swift-format lint -r MonMon MonMonTests`
- Focused tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:MonMonTests/NotificationPreferencesTests test`
- Full tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- iOS compile: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- Physical-device install after user-approved merge into `dev`: `rtk scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/Notifications/` — preferences, authorization state, pure scheduling inputs, and the `UNUserNotificationCenter` adapter.
- `MonMon/Settings/SettingsView.swift` — Notifications card and user-facing permission state.
- `MonMon/App/MonMonApp.swift` — app-owned notification coordinator and active-scene refresh.
- `MonMonTests/Notifications/` — pure preference and schedule-planning tests.
- `MonMon/Resources/Localizable.xcstrings` — English and Vietnamese notification/settings copy.

## Code Style

Store a reminder time as one minute-of-day integer so persistence is independent of an arbitrary `Date`:

```swift
struct ReminderTime: Equatable, Sendable {
    let minuteOfDay: Int

    var hour: Int { minuteOfDay / 60 }
    var minute: Int { minuteOfDay % 60 }
}
```

The app owns one `@Observable` coordinator in `@State` and injects it through the environment. Views own only presentation state; authorization and scheduling side effects remain outside `body`.

## Testing Strategy

- RED/GREEN unit tests for default values, time normalization, and persisted-key behavior.
- Pure tests for the decision that denied authorization leaves a reminder disabled.
- Compile the full iOS target graph to validate Swift 6 concurrency and `UserNotifications` API usage.
- After merge into `dev`, report only whether physical-device build, install, and launch succeed; the owner performs permission-prompt and Settings acceptance testing.

## Boundaries

- Always: keep both reminder toggles independent; expose the selected time only while its reminder is enabled; refresh authorization when the app becomes active; localize visible copy; use accessible native controls.
- Ask first: add more notification types, sync preferences between devices, add notification actions/deep links, or add a master switch.
- Never: request permission on launch, claim delivery is guaranteed, enable reminders after permission denial, add a badge, or store notification preferences in financial backups.

## Success Criteria

- Settings contains an accessible Notifications card with two independent toggles and time pickers.
- Defaults are off, daily time is 20:00, and recurring time is 09:00.
- The first enable action requests `.alert` and `.sound` authorization; subsequent actions respect the recorded system status.
- Denied/revoked status is explained in Settings and offers a route to the app's system settings.
- Disabling a reminder cancels only requests owned by that reminder type.
- No SwiftData migration, network request, badge, or automatic launch-time permission prompt is introduced.

## Open Questions

None. The owner approved the module boundary and defaults on 2026-08-30.
