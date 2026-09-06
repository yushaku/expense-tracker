# Quick expenses UX

Status: Implemented after owner approval. Awaiting owner review and device acceptance.

## Objective
Make quick-expense presets easy to understand and configure from Defaults.
The initial scope is the in-app preset configuration. Keep the current widget
layout and transaction recording contract. Use the existing Catppuccin theme.

## Proposed experience
- Replace the long form of simultaneously editable rows with an adaptive grid of
  preset buttons showing the saved symbol/name, full VND amount and resolved
  category. Tapping a tile edits its preset; it never records an expense.
- Show the current default account above the grid. Missing or deleted defaults
  receive a visible explanation directing the owner to the account selector
  already on this screen.
- Keep the 3 / 6 / 9 selector. Explain widget limits: small shows up to 3,
  medium up to 6, large up to 9. Changing the count saves immediately and
  reloads the widget, retaining hidden presets.
- Open one preset editor at a time with separately labelled name/emoji,
  amount (VND), and expense category fields. Show a live tile preview.
- Show the resolved category beside the transaction-default option, so the
  owner can distinguish an explicit choice from an inherited default.
- Validate each field locally. Reject empty/overlong names, invalid or
  nonpositive/nonwhole amounts, and missing/deleted categories. Explain each
  error alongside its field; do not rely on color alone.
- Save applies just that preset and refreshes the widget. Cancel preserves its
  saved value. Protect an edited draft from accidental dismissal. Keep the
  editor open and show an error if saving fails.
- Use native buttons, clear VoiceOver labels, Dynamic Type and an adaptive
  single-column layout at accessibility sizes. Localize new UI in Vietnamese
  and English. Use the existing app sheet and theme conventions on iOS/macOS.

## Technical scope and structure
- SwiftUI, SwiftData queries and existing App Group UserDefaults storage.
- MonMon/QuickExpense: configuration card, tile/editor views and draft validation.
- MonMon/Resources/Localizable.xcstrings: UI copy.
- MonMonTests/QuickExpense: behavior coverage where persistence or validation changes.
- Reuse QuickExpensePresetStore, TransactionDefaults resolution and appSheet.
- Preserve slot identities, storage keys, legacy decoding, preset order and the
  current rule that presets share the transaction default account.
- No new dependencies, model schema, Liquid Glass, or financial writes from previews.

## Code style
Follow swift-format and the SwiftUI expert checklist. Own draft state in the
editor, pass saved presets as values, and use stable slot identities:

```swift
ForEach(configuration.activePresets) { preset in
    Button { selectedPreset = preset } label: {
        QuickExpensePresetTile(preset: preset)
    }
}
```

## Implementation order
1. Build the read-only preset summary and default-account/category context.
2. Add an isolated editor with field-level validation and Save/Cancel behavior.
3. Wire count persistence and widget refresh; localize and review accessibility.
4. Run quality gates, review the diff, commit on feat/quick-expenses-ux.

## Verification and commands
Swift Testing and in-memory fixtures cover relevant validation/persistence
changes, including preserving hidden presets and explicit/default categories.
Pure visual changes do not need tests that mirror layout implementation.

```sh
rtk proxy xcrun swift-format lint -r MonMon MonMonTests
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

## Boundaries and acceptance
- Always preserve saved configuration on cancel and hidden presets on count changes.
- Always disclose the actual resolved category and default account.
- Always pass format, Mac unit tests and iOS compile before committing.
- Ask the owner to approve this proposal before implementation, and separately
  wait for an explicit merge request before merging into dev.
- Never push, merge main, run Simulator UI validation, or install a feature branch.
- The owner performs UI acceptance on the physical iPhone after an explicitly
  requested merge into dev and scripts/run-iphone.sh Yushaku.

## Open question
The owner may extend the scope to the Home Screen widget's visual design;
that is not included in this initial proposal.

## Delivered verification
- Format lint passed.
- macOS unit suite: 1,118 passed, zero failed or skipped.
- iOS simulator-SDK compile passed for both architectures; no Simulator launched.
- Tests exercise saving one preset after changing the visible count, preserving
  hidden presets, and leaving storage unchanged for an invalid local draft.
- SwiftUI review checked stable identities, private owned state, item-driven
  sheets, draft cancellation, live default resolution, Dynamic Type and labels.
- Physical-device UI acceptance remains with the owner after a requested dev merge.
