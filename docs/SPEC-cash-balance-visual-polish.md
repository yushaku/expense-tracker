# Spec: cash-balance-visual-polish

**Status:** Approved through owner direction (2026-08-23)  
**Depends on:** `cash-balance`

## Objective

Turn the functional cash-balance UI into a calm, premium personal-finance
experience without changing its data, validation, persistence, or navigation
contracts. The same SwiftUI implementation must remain usable on iPhone and Mac.

## Visual Contract

- Use a restrained navy and emerald palette with semantic Light/Dark surfaces.
- Make the exact total the strongest element in a dedicated summary card.
- Render accounts as scannable cards with Cash/Bank icon, name, kind, and balance.
- Give the empty state a clear visual hierarchy and one primary Add Account action.
- Present form inputs in focused sections with a prominent VND amount field.
- Preserve all existing accessibility identifiers and expose errors with icon plus
  text, never color alone.
- Use SF Symbols and platform fonts only; add no image or font assets.

## Tech Stack and Commands

- Swift 6, SwiftUI, SwiftData; iOS 18 and macOS 15.

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
rtk swift format lint --strict --recursive MonMon MonMonTests
```

Because this host has no installed iOS platform runtime, also type-check every app
source directly against `arm64-apple-ios18.0-simulator` with warnings as errors.

## Project Structure

```text
MonMon/
  Design/MonMonTheme.swift       Shared semantic colors and spacing
  Accounts/AccountListView.swift Dashboard, empty state, account cards
  Accounts/AccountEditorView.swift  Form state, toolbar, save/delete orchestration
  Accounts/AccountEditorForm.swift  Shared add/edit account presentation
```

## Code Style

Keep visual primitives semantic and compose native controls:

```swift
Text(VNDCurrency.format(total))
    .font(.system(.largeTitle, design: .rounded, weight: .bold))
    .monospacedDigit()
```

Use the existing formatter, validation, model context, and accessibility contracts.
Do not introduce a generic component framework for two screens.

## Testing Strategy

- Existing unit and persistence tests must pass unchanged.
- Compile both platform branches; Swift warnings remain errors.
- Strict Swift formatting and project plist validation must pass.
- The owner checks visual hierarchy, Dark Mode, Dynamic Type, iPhone keyboard,
  Mac resizing, empty state, populated state, and form errors at runtime.

## Boundaries

### Always do

- Preserve `@Query`, `AccountDraft`, explicit save, rollback, and `Decimal` behavior.
- Keep controls native and keyboard/VoiceOver accessible.
- Keep long account names and large balances from breaking the layout.

### Ask first

- Change user flow, persisted schema, copy language, or accessibility identifiers.
- Add custom assets, fonts, animation packages, or a third-party design system.

### Never do

- Add editing, deletion, transactions, iCloud, network, market data, AI, or MCP.
- Encode financial state only through color.

## Success Criteria

- Total, accounts, Add action, and form hierarchy are visibly clearer than the
  native default List/Form implementation.
- Empty and populated states feel part of one coherent design system.
- Light/Dark Mode, large values, Dynamic Type, and Mac resizing remain usable.
- Existing behavior, tests, identifiers, and local data remain unchanged.

## Open Questions

None. The owner approved the calm premium navy–emerald direction and requested
immediate implementation.
