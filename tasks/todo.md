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

## Follow-up: Apple Pay / bank notification duplicate payments

Requested 2026-09-16. Investigation and implementation pending; not fixed by the
single-screen Quick Capture Shortcut layout change.

Scenario: pay with bank X's credit card through Apple Pay. The Wallet automation
captures the payment, then bank X's notification captures the same payment again.

Confirmed in code: `recordApplePay` and `recordNotification` only look up their own
event-derived IDs in transactions and pending captures. Their fingerprints use
different namespaces (`apple-pay-v1` / `bank-notification-v1`), so exact replay
protection does not reconcile the same payment across these two sources.

- [ ] Reproduce both arrival orders, including delayed bank notifications, with
  one shared destination account and with differing card/account mappings.
- [ ] Inspect actual payloads and define how a Wallet card maps to bank X's credit
  card/account. Do not assume a matching bank name alone identifies the same card.
- [ ] Define cross-source matching using available payment references, card/account,
  amount, currency, merchant and transaction time (not just notification arrival).
  Do not merge solely because two payments have the same amount close together.
- [ ] Define handling for certain vs ambiguous matches. Surface ambiguous pairs for
  review instead of silently deleting or merging legitimate separate payments.
- [ ] Cover pending/pending, saved/pending, saved/saved and already-approved captures;
  preserve both sources for traceability without double-counting the payment.
- [ ] Add regression tests for both arrival orders, retries/concurrent delivery,
  delayed events, different cards, repeated equal-valued purchases, missing fields,
  refunds and reversed/failed payments.
- [ ] Verify on Yushaku with both automations enabled after an approved dev merge.

Until reconciliation exists, use only one automatic capture source per card.
