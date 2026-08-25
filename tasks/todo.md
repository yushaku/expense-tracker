# Tasks: Import Reconciliation and Commit

## Task 1: Add validated import provenance to transaction and transfer models

**Description:** Start with failing tests for a lowercase SHA-256 import id and
old-record defaults. Add optional provenance fields to existing financial models
without changing manual or recurring constructors, then verify the current
private-CloudKit-compatible schema still builds and opens.

**Acceptance criteria:**

- [x] `ImportSourceID` accepts exactly 64 lowercase hexadecimal characters and
      rejects empty, uppercase, short, long, or non-hex input.
- [x] Existing/manual/recurring `MoneyTransaction` values default to no import
      provenance; existing `AccountTransfer` values default both sides to nil.
- [x] New model fields have CloudKit-safe defaults and require no uniqueness
      annotation or raw statement field.

**Verification:**

- [x] New provenance tests fail before implementation and pass afterward.
- [x] Existing transaction, transfer, recurring, and CloudSync tests pass.
- [x] macOS and compile-only iOS builds accept the updated schema.

**Dependencies:** Approved spec and plan

**Files likely touched:**

- `MonMon/Imports/StatementImportProvenance.swift`
- `MonMon/Transactions/MoneyTransaction.swift`
- `MonMon/Transfers/AccountTransfer.swift`
- `MonMonTests/Imports/StatementImportProvenanceTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, five files

## Task 2: Fold duplicate imported records after CloudKit convergence

**Description:** Extend `StoreReconciler` so transactions sharing one validated
import fingerprint and transfers sharing a direction-correct side fingerprint
converge deterministically after sync, while nil-provenance manual and recurring
records remain independent.

**Acceptance criteria:**

- [x] Imported transaction duplicates keep the oldest record with UUID tie-break
      and remove later records sharing the same non-nil fingerprint.
- [x] Transfers sharing source-side or destination-side provenance converge
      without grouping an opposite-side fingerprint or nil value.
- [x] Manual, recurring, conflicting, and unrelated records are not folded.

**Verification:**

- [x] Focused `StoreReconcilerTests` fail first and pass after implementation.
- [x] Reconciliation is idempotent across two consecutive runs.
- [x] Full StoreReconciler and recurring suites remain green.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/App/StoreReconciler.swift`
- `MonMonTests/App/StoreReconcilerTests.swift`

**Estimated scope:** Small, two files

## Checkpoint: Provenance

- [x] Focused provenance, persistence, CloudSync, StoreReconciler, and recurring
      suites pass.
- [x] Model schema compiles for macOS and iOS SDK.
- [x] No raw reference, note, filename, suffix, or PDF metadata is persisted as
      import provenance.
- [x] Commit Tasks 1 and 2 separately before proceeding.

## Task 3: Classify exact, possible, new, and unresolved candidates

**Description:** Build a pure `StatementImportReconciler` over immutable model
snapshots. It preserves parser order, applies direction-specific defaults, and
returns explicit dispositions/resolutions without SwiftData, filesystem, or UI.

**Acceptance criteria:**

- [x] Exact fingerprints identify the correct transaction or transfer side and
      become read-only already-imported rows.
- [x] Possible matches require the approved account/direction/amount/currency/
      local-day fields; note text is ignored and ambiguity stays unresolved.
- [x] New rows receive only valid same-direction category defaults; missing or
      stale inputs remain unresolved deterministically.

**Verification:**

- [x] New reconciler suite fails before implementation and covers every exact,
      possible, ambiguous, new, invalid-default, and ordering case.
- [x] Focused parser and reconciler suites pass together.
- [x] Reconciler source imports no SwiftData, SwiftUI, App Group, or UserDefaults.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMon/Imports/StatementImportReconciler.swift`
- `MonMonTests/Imports/StatementImportReconcilerTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, three files

## Task 4: Resolve and remember the statement account safely

**Description:** Add a small injected UserDefaults boundary keyed by bank and
account suffix. It resolves only current VND accounts and writes a choice only
after the caller reports successful financial commit.

**Acceptance criteria:**

- [x] A valid bank/suffix mapping resolves its current account; missing suffix,
      malformed UUID, stale id, wrong currency, or deleted account resolves nil.
- [x] Saving replaces only the exact bank/suffix key and never creates a
      bank-wide fallback.
- [x] Tests use an isolated suite and leave standard owner defaults untouched.

**Verification:**

- [x] New mapping suite fails first and passes after implementation.
- [x] Existing transaction-default tests remain green.
- [x] Mapping keys and errors expose no suffix or account id in logs or UI text.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/Imports/StatementAccountMapping.swift`
- `MonMonTests/Imports/StatementAccountMappingTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Small, three files

## Checkpoint: Reconciliation

- [x] Reconciler and mapping suites pass with deterministic Vietnam-calendar
      behavior.
- [x] Possible/ambiguous matches remain unresolved and block commit.
- [x] Defaults cannot silently select a different account or category.
- [x] Commit Tasks 3 and 4 separately before persistence work.

## Task 5: Commit and link ordinary transactions idempotently

**Description:** Add a dedicated-context commit service for transaction, link,
skip, and exact-import resolutions. It re-fetches current models, reruns
eligibility, validates the complete request, and saves all changes once.

**Acceptance criteria:**

- [x] Valid transaction resolutions create `MoneyTransaction` through existing
      draft validation with one validated `sourceImportID`.
- [x] Eligible links attach provenance without creating a record; exact and
      skipped rows make no write.
- [x] Any stale/invalid/unresolved row rolls back the whole request, and a repeat
      request cannot create a second financial record.

**Verification:**

- [x] New in-memory commit-service tests fail first and pass after implementation.
- [x] Failure tests prove zero partial transaction or provenance writes.
- [ ] Existing transaction persistence and summary suites remain green.

**Dependencies:** Task 4

**Files likely touched:**

- `MonMon/Imports/StatementImportCommitService.swift`
- `MonMonTests/Imports/StatementImportCommitServiceTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, three files

## Task 6: Commit/link transfers and recover staged cleanup failures

**Description:** Extend the same service with direction-correct transfer creation
and side linking, then orchestrate account mapping and staged removal after the
financial save. Model saved-but-not-cleaned as an explicit retryable result.

**Acceptance criteria:**

- [ ] Expense/income candidates create the correct source/destination endpoints;
      links fill only an eligible empty side and never create income/expense.
- [ ] Historical transfers skip current-balance enforcement while retaining
      positive amount, existing distinct accounts, and currency validation.
- [ ] Save failure leaves mapping/PDF untouched; cleanup failure preserves saved
      records, reports cleanup-needed, and retries without another financial write.

**Verification:**

- [ ] Focused transfer, linking, all-exact, save-failure, and cleanup-retry tests
      fail first and pass afterward.
- [ ] Balance and Spending-summary assertions prove transfers remain neutral.
- [ ] Existing transfer, intake-store, and inbox-service suites remain green.

**Dependencies:** Task 5

**Files likely touched:**

- `MonMon/Imports/StatementImportCommitService.swift`
- `MonMon/Imports/StatementImportInboxService.swift`
- `MonMonTests/Imports/StatementImportCommitServiceTests.swift`
- `MonMonTests/Imports/StatementImportInboxServiceTests.swift`

**Estimated scope:** Medium, four files

## Checkpoint: Persistence

- [ ] Full import, transaction, transfer, persistence, and balance suites pass.
- [ ] One save contains every financial/provenance mutation or none.
- [ ] Repeated and interrupted requests are idempotent.
- [ ] Staged bytes are removed only after saved provenance exists.
- [ ] Commit Tasks 5 and 6 separately before UI/state integration.

## Task 7: Add observable reconciliation and commit phases

**Description:** Add a main-actor review model that composes parsed preview,
current model snapshots, remembered account, row choices, commit readiness,
commit progress, saved result, and cleanup retry without weakening existing
stale-preview protection.

**Acceptance criteria:**

- [ ] Selecting/changing statement account deterministically rebuilds rows and
      preserves only still-valid owner choices.
- [ ] State distinguishes reviewing, committing, saved, cleanup-needed, and
      failed; stale tasks cannot overwrite another statement.
- [ ] Commit readiness is true only for complete parser output and currently
      valid, fully resolved rows.

**Verification:**

- [ ] New state tests fail first for phase transitions, stale results, account
      changes, retained choices, retry, and content-free failures.
- [ ] Existing inbox-state tests remain green.
- [ ] Swift 6 actor/sendability checks pass.

**Dependencies:** Task 6

**Files likely touched:**

- `MonMon/Imports/StatementImportReview.swift`
- `MonMon/Imports/StatementImportInbox.swift`
- `MonMonTests/Imports/StatementImportReviewTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, four files

## Task 8: Add account selection and focused row-resolution editor

**Description:** Extend the statement preview with the required statement account
selector, visible row statuses, and a focused editor for category/note,
skip/new/link, or transfer account. Parsed source facts stay read-only.

**Acceptance criteria:**

- [ ] Current or remembered account appears above rows; missing account visibly
      blocks commit without hiding parsed review.
- [ ] Each row exposes its status and only the controls valid for its disposition
      and resolution; possible matches never preselect link or new.
- [ ] Source amount/direction/date/reference/page remain immutable and untrusted
      text never enters accessibility identifiers.

**Verification:**

- [ ] iOS SDK compiles after view, localization, and project wiring changes.
- [ ] Code inspection covers 44-point targets, VoiceOver status, light/dark, and
      English/Vietnamese strings.
- [ ] No UI control writes SwiftData or removes staged files directly.

**Dependencies:** Task 7

**Files likely touched:**

- `MonMon/Imports/StatementImportRowEditorView.swift`
- `MonMon/Imports/StatementImportPreviewView.swift`
- `MonMon/Resources/Localizable.xcstrings`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, four files

## Task 9: Add commit confirmation, results, cleanup retry, and count refresh

**Description:** Finish the owner flow with reviewed counts, a disabled/enabled
primary action, content-free confirmation, progress, success dismissal, and a
distinct saved-but-cleanup-needed retry path that refreshes all Inbox surfaces.

**Acceptance criteria:**

- [ ] Confirmation names transaction/transfer/link/skip counts and never source
      values; incomplete/unresolved state cannot invoke commit.
- [ ] Success removes the statement from navigation and refreshes Inbox/banner;
      all-exact review uses confirmed cleanup with no financial write.
- [ ] Save failure retains choices; cleanup failure states records are saved and
      offers idempotent retry without presenting import as failed.

**Verification:**

- [ ] State/service suites cover confirmation request, double-tap protection,
      success refresh, all-exact cleanup, save failure, and cleanup retry.
- [ ] iOS SDK build passes and review confirms no direct SwiftData/filesystem UI.
- [ ] Physical build/install/launch succeeds on `Yushaku`; owner interaction
      remains the later acceptance checkpoint.

**Dependencies:** Task 8

**Files likely touched:**

- `MonMon/Imports/StatementImportPreviewView.swift`
- `MonMon/Imports/StatementImportInboxView.swift`
- `MonMon/Transactions/TransactionListView.swift`
- `MonMon/Resources/Localizable.xcstrings`
- `MonMonTests/Imports/StatementImportReviewTests.swift`

**Estimated scope:** Medium, five files

## Checkpoint: UI

- [ ] One complete statement can be fully resolved without leaving preview.
- [ ] Exact, possible, transfer, skip, unresolved, saving, saved, and cleanup
      states are accessible and visually distinct.
- [ ] Financial records appear only after confirmed commit.
- [ ] Pending-count surfaces refresh only after cleanup succeeds.
- [ ] Commit Tasks 7, 8, and 9 separately.

## Task 10: Review, verify, deploy to Yushaku, and hand off acceptance

**Description:** Run every repository gate, inspect schema/matching/persistence/UI
diffs for correctness and privacy, then build, install, and launch on the
physical phone. The owner performs the actual import and verifies the resulting
transaction, transfer, balances, and cleared Inbox.

**Acceptance criteria:**

- [ ] Full automated gates and review pass with no unresolved high/medium issue.
- [ ] Physical build, install, and launch succeed on `Yushaku`.
- [ ] Repository contains no real statement, extracted content, local path,
      exposed hash/reference, generated output, or unrelated change.

**Verification:**

- [ ] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- [ ] `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- [ ] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- [ ] `rtk scripts/run-iphone.sh Yushaku`
- [ ] Owner hands-on acceptance on physical `Yushaku`.

**Dependencies:** Task 9

**Files likely touched:**

- `SPEC-import-reconciliation.md` only if an approved requirement changes
- `tasks/plan.md`
- `tasks/todo.md`

**Estimated scope:** Small, verification and documentation

## Checkpoint: Complete

- [ ] Approved spec and plan success criteria are met.
- [ ] Definition of Done is satisfied.
- [ ] Owner verifies imported records, transfer neutrality, duplicate prevention,
      and staged cleanup on `Yushaku`.
