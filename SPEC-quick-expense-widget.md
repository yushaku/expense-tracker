# Spec: Quick Expense Widget

## Objective

Add an iPhone home-screen widget with three one-tap expense presets. The
defaults are Coffee (`☕`, 35,000 VND), Lunch (`🍜`, 50,000 VND), and Fuel
(`⛽`, 100,000 VND). The owner can edit each preset's emoji and amount from the
existing in-app transaction Defaults screen. Tapping a widget button records an
ordinary expense using the current default account and expense category, then
WidgetKit reloads the widget timeline.

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
- Build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
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
try store.save([preset])
```

Use native `Button(intent:)` controls in the widget, theme tokens in the app,
stable enum identity for all three rows, and explicit accessibility labels.

## Testing Strategy

- Unit-test default presets, round-trip app-group persistence, symbol/amount
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
  and category, keep presets positive and non-empty, share only preset settings
  through the app group, and let WidgetKit reload after intent completion.
- Ask first: per-preset account/category settings, more than three presets,
  changing the SwiftData store layout, or a new dependency.
- Never: stage a failed preset as pending review, create duplicate stores, merge
  to `dev`/`main`, push, or install on iPhone without explicit approval.

## Success Criteria

- A small and medium Quick Expense widget show the three configured presets.
- Defaults are `☕ 35k`, `🍜 50k`, and `⛽ 100k`.
- The owner can edit every emoji and amount on the transaction Defaults screen;
  valid changes persist across launches and refresh installed widgets.
- One widget-button tap creates exactly one expense with today's timestamp, the
  preset emoji as its note, and the current default account/category.
- Missing or stale transaction defaults create neither a transaction nor a
  pending-review record.
- Returning from the intent causes WidgetKit to reload the timeline.
- The action runs in the app process without foregrounding MonMon on iOS 18+.
- Full tests, format lint, and a non-Simulator iOS SDK build pass.

## Open Questions

None. The supplied examples define the three defaults; configuration is limited
to emoji and amount, while account/category continue to come from the existing
transaction defaults.
