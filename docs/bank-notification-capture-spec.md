# Bank notification capture

## Objective and accepted flow

The user chooses a bank app in an iOS 27 Shortcuts notification automation,
then forwards its text to MonMon. Settings explains this setup and selects the
default destination account. An optional account parameter on the action lets
each automation target a different account.

## Behavior

- A separate Record Bank Notification action accepts text, source app label,
  received date, and an optional destination account.
- Notification capture is local. It does not request access to other apps.
- Review is the default. The user may enable automatic saving after checking
  sample notifications. Only a single explicitly labelled, signed VND transaction
  amount is accepted; balances, bare numbers, OTPs, failed/pending transactions,
  transfers and unknown formats require review. There are no verified bank-specific
  adapters yet. Existing income/expense category defaults apply.
- Preserve the supplied notification text and source in the note. Use the supplied
  received date, not an inferred transaction date.
- The same text, source, account and received date produces the same record id.
  Replaying that event cannot add a second pending item or transaction, including
  after review. Different dates distinguish otherwise identical transactions.
  This is event retry deduplication, not reconciliation against PDF imports.
- Empty input or a deleted destination account fails without creating a record.
- Settings offers a sample preview that never saves and a link to Needs review.
- The Shortcuts trigger and the notification data available while locked still
  require user acceptance testing on the physical iPhone.

## Implementation and style

Swift, App Intents, SwiftData and SwiftUI; follow existing `TransactionCaptureService`
and `ParsedTransactionCapture` types. Parsing is pure; writes stay on MainActor,
use an isolated ModelContext and SyncWriteGate. No new schema or dependencies.
Code belongs in MonMon/Transactions, MonMon/App and MonMon/Settings; tests in
MonMonTests/Transactions; English/Vietnamese strings in the existing catalog.

## Work and validation

1. Add parser, atomic event capture, and tests for rejection and idempotency.
2. Expose the action and account query; add setup, defaults and preview UI.
3. Update documentation and translations; run the full quality gates.

```sh
rtk proxy xcrun swift-format lint -r MonMon MonMonTests
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Always preserve financial write validation and stage uncertainty. Never infer a
bank balance as a transaction amount. Commit on the feature branch; user review
and an explicit merge request precede dev installation. No simulator runtime or
production installation. Bank-specific samples are needed to extend coverage.

## Platform source

Apple: https://developer.apple.com/videos/play/wwdc2026/310/ — notification
automations run for a selected app and support content filters. The exact
notification-to-action field mapping must be verified on the user's iPhone.

## Verification (2026-09-15)

- Swift format lint passed.
- Complete macOS test suite passed: 1,272 tests, no failures or skips (1,305
  executions including parameterized cases).
- iOS compile check passed using the installed iPhoneSimulator 26.5 SDK, arm64
  and x86_64; no Simulator was launched.
- Physical iOS 27 notification delivery and UI acceptance remain unverified.
  The branch has not been merged into dev or installed on the phone.
