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
- Use the value of a single nonempty `ND:` line as the note (as in TPBank
  notifications). Trim surrounding whitespace, preserve case/accents, and support
  LF, CRLF and CR line endings. Match the uppercase label only at a line's start
  after whitespace. Missing, empty or multiple `ND:` lines retain the complete
  notification and source as the note. Shortcuts must still forward the full text;
  no Match Text action is needed. This applies to new captures, not existing notes.
- Preserve the supplied notification text and source separately in the capture's
  `rawText` for review. Amount parsing, safety checks and event identity continue
  to use the full message. Extracting `ND:` does not add support for TPBank's `PS:`
  amount format; those messages still need review. Use the supplied received date,
  not an inferred transaction date.
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
- Complete macOS test suite passed: 1,275 tests, no failures or skips (1,315
  executions including parameterized cases).
- Note-extraction regression tests failed before the change and passed afterward.
  They cover the TPBank sample, persisted notes/raw text, retry deduplication,
  whitespace/Unicode, line endings, and missing/empty/ambiguous fields.
- iOS compile check passed using the installed iPhoneSimulator 26.5 SDK, arm64
  and x86_64; no Simulator was launched.
- Physical iOS 27 notification delivery and UI acceptance remain unverified.
  The note-extraction change has not been merged into dev or installed on the phone.
