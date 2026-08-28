# Spec: Per-Preset Quick Expense Categories

## Objective

Let the owner choose an expense category for every Quick Expense preset. A
widget action must record with that configured category instead of always
falling back to the global Food/default category.

## Tech Stack

- Swift 6, SwiftUI, SwiftData, WidgetKit, and App Intents.
- Existing app-group `UserDefaults` Quick Expense configuration.
- Existing `TransactionCategory`, `TransactionCaptureService`, and transaction
  default account.
- Swift Testing for persistence, compatibility, and transaction behavior.

## Commands

- Focused tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:MonMonTests/QuickExpensePresetStoreTests -only-testing:MonMonTests/TransactionCaptureServiceTests`
- Full tests: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- Lint: `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension MonMonQuickExpenseWidget`
- Build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build`

## Project Structure

- `MonMon/QuickExpense/`: category-aware preset contract, draft, and editor.
- `MonMon/App/`: typed Quick Expense recording dependency registration.
- `MonMon/Transactions/`: category validation and ready-only transaction
  preparation.
- `MonMonTests/QuickExpense/` and `MonMonTests/Transactions/`: compatibility
  and persistence tests.

## Code Style

Keep category identity typed and optional only for the explicit default mode:

```swift
let preset = try QuickExpensePreset(
    slot: .coffee,
    symbol: "☕",
    amount: 35_000,
    categoryID: foodAndDrink.id
)
```

## Migration and Compatibility

- Add `categoryID: UUID?` to each preset's app-group payload.
- Existing payloads without the field decode with `categoryID == nil` and keep
  all name/emoji, amount, count, and ordering values.
- `nil` means “Transaction default” and preserves current behavior until the
  owner selects a category.
- A non-nil category must identify a current expense category. A deleted or
  income category is stale and must not silently fall back to Food/default.

## UI Behavior

- Each visible preset uses one compact Name–Price–Category surface with a native
  category picker and no separate per-field labels.
- Options contain “Transaction default” plus all current expense categories.
- A stale explicit selection displays a choose state and blocks saving while
  that preset is visible.
- Picker labels and validation feedback are localized and accessible.

## Testing Strategy

- Prove category IDs round-trip through app-group persistence.
- Prove old JSON without category IDs decodes without data loss.
- Prove a configured category overrides the global default.
- Prove nil uses the global default for compatibility.
- Prove a stale or income category records nothing.
- Run the full suite, recursive format lint, and generic iOS build.

## Boundaries

- Always: use the transaction default account; validate category kind and
  existence immediately before writing; preserve legacy data.
- Ask first: per-preset accounts, category creation inside this editor, or
  displaying category names in the widget.
- Never: duplicate SwiftData in the widget, silently switch a stale explicit
  category to Food, merge, push, or install without approval.

## Success Criteria

- Every visible Quick Expense preset can select its own expense category.
- Widget taps create exactly one transaction with the selected category.
- Legacy presets continue using Transaction default until configured.
- Deleted or non-expense configured categories create no transaction.
- Existing success feedback and widget refresh behavior remain unchanged.

## Open Questions

None.
