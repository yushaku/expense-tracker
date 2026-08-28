# Spec: Quick Expense Widget

## Objective

Add an iPhone home-screen widget with a configurable 3, 6, or 9 one-tap expense
presets. The first defaults are Coffee (`☕`, 35,000 VND), Lunch (`🍜`, 50,000
VND), and Fuel (`⛽`, 100,000 VND). The owner can choose the count and edit each
preset's short name, amount, and expense category from the existing in-app
transaction Defaults screen. Tapping a widget button records an ordinary
expense using the current default account and that preset's category, then
WidgetKit reloads the widget timeline and briefly shows a saved confirmation.
Existing emoji values remain valid short names. See
`SPEC-configurable-quick-expenses.md` and
`SPEC-quick-expense-categories.md` for expanded behavior and migration.

## Tech Stack

- Swift 6, SwiftUI, WidgetKit, and App Intents.
- SwiftData through the existing `TransactionCaptureService` and app-owned
  `ModelContainer`.
- App-group `UserDefaults` for the small preset configuration shared with the
  widget extension.
- Swift Testing for preset validation/persistence and intent persistence.
- iOS 26 background intent modes and Apple's `ForegroundContinuableIntent`
  compatibility conformance for iOS 18-25 app-process execution.

## Commands

- Test: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- Lint: `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension MonMonQuickExpenseWidget`
- Build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build`
- Physical-device validation after an approved merge to `dev` only:
  `scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/QuickExpense/`: shared preset model/store, app intent dependency, and
  in-app editor.
- `MonMonQuickExpenseWidget/`: WidgetKit extension, timeline provider, widget
  view, Info.plist, and entitlements.
- `MonMon/App/MonMonApp.swift`: app-process intent dependency registration.
- `MonMon/Transactions/TransactionCaptureService.swift`: ready-only capture
  path that never stages a preset for later review.
- `MonMonTests/QuickExpense/`: preset and persistence tests.

## Code Style

Use typed preset slots and validate before persistence:

```swift
let preset = try QuickExpensePreset(
    slot: .coffee,
    symbol: "☕",
    amount: 35_000
)
let presets = [preset] + Array(QuickExpensePreset.defaults.dropFirst())
try store.save(presets)
```

The persisted `symbol` key remains unchanged for compatibility, but its
user-facing value is a trimmed, nonempty name of at most 16 characters.

Use native `Button(intent:)` controls in the widget, theme tokens in the app,
stable enum identity for all rows, and explicit accessibility labels.

## Testing Strategy

- Unit-test default presets, round-trip app-group persistence, name/amount
  validation, and recovery from malformed stored data.
- Add a ready-only capture test proving a valid preset creates one transaction
  and no pending-review item; add a missing-default test proving it writes
  neither.
- Compile the WidgetKit extension through the iOS SDK build.
- Run the full macOS tests and recursive format lint.
- After review and merge to `dev`, the owner verifies add/edit/widget behavior
  on the physical iPhone. No Simulator runtime validation.

## Boundaries

- Always: create an ordinary expense, use the current default expense account
  and each preset's valid expense category, keep presets positive and
  non-empty, share only preset settings through the app group, and let
  WidgetKit reload after intent completion.
- Ask first: per-preset account settings, more than nine presets,
  changing the SwiftData store layout, or a new dependency.
- Never: stage a failed preset as pending review, create duplicate stores, merge
  to `dev`/`main`, push, or install on iPhone without explicit approval.

## Success Criteria

- Small, medium, and large Quick Expense widgets show up to 3, 6, and 9
  configured presets.
- Defaults are `☕ 35k`, `🍜 50k`, and `⛽ 100k`.
- The owner can edit every short name, amount, and expense category on the
  transaction Defaults screen; valid changes persist across launches and
  refresh installed widgets.
- One widget-button tap creates exactly one expense with today's timestamp, the
  preset name as its note, the current default account, and its configured
  category.
- Missing or stale account/category configuration creates neither a transaction
  nor a pending-review record.
- Returning from the intent causes WidgetKit to reload the timeline and show a
  transient saved state on the tapped preset.
- The action runs in the app process without foregrounding MonMon on iOS 18+.
- Full tests, format lint, and a non-Simulator iOS SDK build pass.

## Open Questions

None. Configuration is limited to count, short name, amount, and expense
category; the account continues to come from the existing transaction defaults.
