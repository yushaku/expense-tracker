# Apple Pay capture

Status: plan approved; implemented on `feat/apple-pay-capture`. Physical Wallet
acceptance testing remains with the owner after an explicitly requested dev merge.

## Objective and scope

Receive new Wallet transaction events through a user-created Shortcuts automation.
Add a dedicated Record Apple Pay Transaction action and a short Settings setup page.
Reuse MonMon's existing pending-review and transaction-saving flow. No Wallet history
access, payment initiation, bank credentials, or external service is involved.

Assumptions: review-first by default, optional automatic saving, expenses in VND,
and an explicitly selected MonMon account for each card's automation. These defaults
are conservative interpretations of the user's approval on 2026-09-16.

## Behavior and success criteria

- Accept amount with currency as `IntentCurrencyAmount?`, merchant, required event
  date, optional card label, and selected MonMon account through App Intents.
  Confirm Wallet variable mappings on the phone;
  do not promise every issuer supplies every field or a transaction identifier.
- Store merchant as the note. Retain bounded source details in the review payload.
  Treat all supplied values as untrusted, including manual action invocation.
- Default to pending review without changing totals. Automatic saving is a separate
  Apple Pay preference, not inherited from bank-notification preferences. It requires
  a positive, finite, supported VND amount, merchant, valid account/category and date.
- Missing or ambiguous fields stay in review; invalid oversized input fails safely.
  Never use a card number or merchant digits as an amount. Missing/foreign currency
  must not become VND silently: retain original details for review, leave the VND
  amount unset, and require a deliberate amount entry before saving.
- Retry identity includes the original event time and canonical event fields, scoped
  to the destination account. Exact retries create only one pending item/transaction;
  equal payments at different times remain distinct. A newly generated timestamp is
  a different event, so the guide must not promise deduplication across arbitrary retries.
- No heuristic cross-source deletion: an Apple Pay event and a bank notification
  lack a proven shared ID. Warn users to use one automatic capture source per card.
- Explain that an observed Wallet trigger is not proof of final bank settlement;
  automatic saving is opt-in and review remains available for reconciliation.
- Settings opens via NavigationLink, consistent with Bank notifications. Provide
  concise setup, account preference, review/automatic mode, and last-result status
  without logging payment details. Localize user-facing text in Vietnamese/English.

## Structure and style

Swift, SwiftUI, App Intents, SwiftData and Swift Testing; no new dependencies or schema.
Use `MonMon/Transactions/` for event validation/service integration,
`MonMon/App/` for the action, `MonMon/Settings/` for UI,
`MonMonTests/Transactions/` for tests, and explicit Xcode project file registration.
Match existing Decimal amounts, immutable Sendable values and MainActor persistence:

```swift
return try service.recordApplePay(event, accountID: accountID)
```

## Validation commands

Run sequentially from the repo root, retaining the shared build cache:

```sh
rtk proxy xcrun swift-format lint -r MonMon MonMonTests
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Use in-memory SwiftData tests for default review, opt-in saving, invalid/missing fields,
non-VND safety, deleted accounts/categories, exact retries before/after approval,
different timestamps, and persistence failures. Existing bank-notification tests must
remain unchanged and pass. Compile App Intents metadata; the user validates actual
Wallet field delivery and UI on Yushaku after a separately requested dev merge.

## Boundaries

- Always: preserve the bank-notification flow, data integrity, SyncWriteGate, existing
  review editing, Decimal money handling and repository quality gates.
- Ask first: schema/dependency changes, widening currency/payment coverage, merge or push.
- Never: assume trigger delivery or settlement guarantees, read payment credentials,
  invent a shared iCloud Shortcut URL, install from a feature branch or run a Simulator.

## Sources and open validation

Apple documents card-tap transaction automations:
https://support.apple.com/en-lamr/guide/shortcuts/apd65c67538a/ios

Developer reports (not an Apple guarantee) describe timeouts and declined-payment
triggers: https://developer.apple.com/forums/thread/765516

Still requires physical validation: iOS 27 Wallet input properties, amount/currency
conversion, locked-device execution and delivery behavior for the user's card.
A downloadable shared template needs a real tested iCloud link; no placeholder button.

## Implementation and verification

The Apple Pay service validates bounded fields and finite dates, separates its
preferences from bank notifications, and performs synchronous MainActor lookup/save
through the existing SyncWriteGate. Review retains the deterministic event ID.
Tests cover default review, independent opt-in, canonical retries before/after
approval, distinct event dates/cards/accounts/currencies, unsupported currency,
invalid amounts, missing fields, invalid explicit accounts, bounded input, rollback
under a sync write lock, and dependency status reporting.

On 2026-09-16, Xcode 27: format lint passed; the full macOS suite passed 1,284 tests
(1,333 executions including parameterized cases), zero failures/skips. New tests were
first run against missing event/service and dependency implementations and failed,
then passed after implementation. App Intents metadata includes the action, native
currency input, optional account/card/merchant, required date, and background mode.
iOS 27 simulator-SDK compilation passed for arm64 and x86_64 (no Simulator runtime).
