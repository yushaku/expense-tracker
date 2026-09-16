# Apple Pay capture tasks

Plan/tasks approved by the user. Commands and shared quality gates are in
`docs/apple-pay-capture-spec.md`.

## 1. Capture service (no dependencies)

- [x] Add bounded, validated Apple Pay event handling and independent preferences.
- [x] Default to review; allow opt-in valid VND saving; preserve unknown/foreign data
  without converting its amount to VND.
- [x] Prove exact retry idempotency and preserve distinct equal-valued payments.

Files: new ApplePayCapture.swift, TransactionCaptureService.swift,
TransactionCaptureParser.swift, TransactionCaptureServiceTests.swift, project.pbxproj.
Verify: focused Swift Testing cases, then existing bank-notification regression cases.

## 2. Shortcut action (depends on 1)

- [x] Add Record Apple Pay Transaction with explicit typed fields and account choice.
- [x] Test bridge outcomes for saved/review/duplicate/error without foreground prompts.
- [x] Localize parameter descriptions, errors and results; compile App Intents metadata.

Files: TransactionCaptureIntent.swift, TransactionCaptureServiceTests.swift,
Localizable.xcstrings; split a dedicated action file if needed and register it.
Verify: focused dependency tests and iOS compile command in the spec.

## Checkpoint

- [x] Parser/persistence/action tests pass with no bank-notification behavior changes.

## 3. Settings and handoff (depends on 2)

- [x] Add navigation page, separate account/auto-save preferences and last-result status.
- [x] Add concise Wallet setup, review/settlement limitations and duplicate-source warning.
- [x] Run format, whole unit suite and iOS compile; review and update docs.
- [x] Commit feature code after staged-diff inspection; documentation recorded separately.

Files: ApplePayCaptureSettingsView.swift, SettingsView.swift, Localizable.xcstrings,
project.pbxproj, README.md. Update the spec/task status as implementation progresses.
Verify: project SwiftUI correctness checklist; no Simulator UI testing.

Verified 2026-09-16 with Xcode 27: format lint passed, 1,284 macOS tests passed
(1,333 parameterized executions), iOS SDK compilation passed for both architectures.
Metadata confirms the native currency input and background action. No device install,
merge or push performed; actual Wallet delivery is not inferred from these checks.

## Owner acceptance (only after requested dev merge)

- [ ] On Yushaku verify field mapping and capture of a real Wallet payment.
- [ ] Verify review default, opt-in saving, account selection and navigation.
- [ ] Verify replaying identical input does not duplicate an approved capture.
