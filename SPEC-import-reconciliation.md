# Spec: Import Reconciliation and Commit

Module id: `import-reconciliation`

## Objective

Turn a complete, locally parsed bank statement into reviewed MonMon financial
records without double-counting an earlier import or treating movement between
the owner's own accounts as income or expense.

The owner assigns the statement to one MonMon cash account, resolves each new
candidate as a categorized transaction, an internal transfer, or a skipped row,
then commits the resolved set once. Exact prior imports are recognized from
content-derived provenance. Similar existing records remain owner decisions;
MonMon never silently deletes, merges, or imports an uncertain match.

This module completes the domain and persistence dependency required before the
existing Import Inbox can gain editing and commit controls.

### Assumptions

1. One bank statement belongs to one `CashAccount`. The selection applies to all
   candidates in that statement.
2. When both bank and account suffix are available, MonMon remembers the chosen
   account locally by `bank + last four`. A valid mapping takes precedence;
   otherwise the current valid transaction default account is preselected.
3. A parsed candidate's existing SHA-256 id is its immutable source fingerprint.
   Financial records store only that fingerprint, never the PDF, statement id,
   source reference, or raw statement metadata as provenance.
4. Parsed amount, direction, and timestamp are source facts and are not editable
   in this module. The owner can edit the resulting note, choose a category,
   skip a row, or classify it as an internal transfer.
5. Existing transaction defaults prefill income and expense categories. This
   module adds no merchant classifier or category-learning rules.
6. Transfer classification is explicit. MonMon can suggest an existing transfer
   from account-side, amount, and local calendar day, but never infers a transfer
   from note text or commits one without the owner selecting the other account.
7. The SwiftData commit succeeds before the staged statement is removed. If
   filesystem cleanup fails, provenance makes reopening and cleanup idempotent.
8. Import provenance syncs with the same private CloudKit store as its financial
   record. It contains hashes only and is never displayed, logged, or exported.

## Domain Contract

### Persisted provenance

Add optional, default-`nil` fields to existing models:

```swift
@Model
final class MoneyTransaction {
    // Existing fields remain unchanged.
    var sourceImportID: String?
}

@Model
final class AccountTransfer {
    // Fingerprint seen on the statement for the account money left.
    var sourceAccountImportID: String?

    // Fingerprint seen on the statement for the account money reached.
    var destinationAccountImportID: String?
}
```

Rules:

- A manually entered or recurring transaction keeps `sourceImportID == nil`.
- An imported ordinary transaction stores exactly one candidate fingerprint.
- A transfer may initially store one side. Importing the opposite account's
  statement can attach its candidate fingerprint to the corresponding empty
  side without creating a second `AccountTransfer`.
- Import ids must pass the same lowercase 64-character SHA-256 validation used
  by staged content ids before they enter SwiftData.
- No uniqueness annotation is added because private CloudKit does not provide a
  cross-device uniqueness transaction. Reconciliation remains deterministic
  and idempotent at the service boundary, and `StoreReconciler` folds duplicate
  imported records that share the same non-`nil` side fingerprint.

### Reconciliation types

Exact names may simplify during planning, but the behavior remains:

```swift
enum ImportCandidateDisposition: Equatable, Sendable {
    case newTransaction
    case exactImportedTransaction(transactionID: UUID)
    case possibleTransaction(transactionID: UUID)
    case exactTransfer(transferID: UUID)
    case possibleTransfer(transferID: UUID)
}

enum ImportRowResolution: Equatable, Sendable {
    case transaction(categoryID: UUID, note: String)
    case newTransfer(otherAccountID: UUID, note: String)
    case linkTransaction(transactionID: UUID)
    case linkTransfer(transferID: UUID)
    case skip
    case unresolved
}

struct ReconciledImportRow: Identifiable, Equatable, Sendable {
    let candidate: BankTransactionCandidate
    let disposition: ImportCandidateDisposition
    var resolution: ImportRowResolution
}
```

The reconciliation service accepts parsed candidates, the selected statement
account, current accounts/categories/transactions/transfers, and stored defaults.
It returns rows in parser order plus an import summary. It performs no write.

## Matching Rules

Rules are intentionally narrow and ordered from strongest to weakest.

### Exact prior import

- A candidate is an exact imported transaction when its fingerprint equals a
  non-`nil` `MoneyTransaction.sourceImportID`.
- For an expense candidate, it is an exact transfer when its fingerprint equals
  `AccountTransfer.sourceAccountImportID` and the statement account is that
  transfer's source.
- For an income candidate, it is an exact transfer when its fingerprint equals
  `AccountTransfer.destinationAccountImportID` and the statement account is that
  transfer's destination.
- Exact matches are read-only, excluded from commit counts, and cannot be
  changed to “import anyway.” One source row must never create two records.

### Possible ordinary transaction

A non-exact candidate is a possible transaction only when one existing
`MoneyTransaction` has all of:

- the selected statement account;
- the same direction and exact `Decimal` amount;
- VND currency; and
- the same local calendar day in `Asia/Ho_Chi_Minh`.

One match can be linked or ignored. Multiple matches are displayed as ambiguous
and must be resolved by choosing one, skipping, or importing a new transaction.
Note text is displayed for comparison but never participates in matching.

Linking writes the candidate fingerprint onto the chosen transaction. A record
that already carries a different import fingerprint cannot be linked.

### Possible internal transfer

A non-exact candidate can match an existing `AccountTransfer` when:

- the statement account is on the side implied by candidate direction;
- the corresponding side fingerprint is empty;
- the transfer amount and currency match exactly; and
- the transfer occurred on the same local calendar day.

Linking fills only the empty side fingerprint and creates no financial record.

Creating a new transfer requires a distinct other `CashAccount`:

- expense candidate: statement account is source, chosen account is destination;
- income candidate: chosen account is source, statement account is destination.

Historical imports call `TransferDraft` with no current-balance restriction.
They must not fail merely because today's source balance is lower than a past
transfer amount.

## Defaults and Owner Input

### Statement account

- The preview adds one required account selector above candidate rows.
- A valid remembered mapping preselects the account. Without one, the current
  valid transaction default account is preselected.
- Selecting an account stores or replaces the local mapping only after a
  successful commit. Cancelling review does not change defaults.
- A missing account suffix never creates a broad bank-level mapping.

### Candidate rows

- Exact matches show **Already imported** and need no action.
- A new transaction starts selected, with note from the candidate and category
  from the existing direction-specific transaction default.
- A missing or stale category leaves the row unresolved.
- The owner can change category, edit the resulting note, skip the row, or
  switch between ordinary transaction and transfer.
- Transfer mode requires choosing the other account and shows direction in
  plain language. It never shows a category.
- Possible matches start unresolved. MonMon does not preselect “link” or “new.”
- A skipped row creates no record and no provenance; it may appear again in an
  overlapping future statement.

## Commit Contract

Commit is allowed only when:

- the parsed statement is complete and has no parser issues;
- a current statement account is selected;
- every non-exact row is resolved;
- every transaction resolution has an existing category of the same direction;
- every transfer has two different existing accounts;
- every link target still exists and remains eligible; and
- all candidate fingerprints are structurally valid.

The commit service uses a dedicated `ModelContext` so failure cannot roll back
unrelated UI edits. Immediately before writing it fetches current records and
re-runs exact/eligibility checks to close the time-of-check/time-of-use gap.

One SwiftData save performs all financial/provenance changes:

- insert each resolved new `MoneyTransaction` with `sourceImportID`;
- insert each resolved new `AccountTransfer` with the fingerprint on the side
  represented by the statement;
- attach a fingerprint when linking an eligible existing record;
- write no model for skipped or already-imported rows.

If validation or save fails, the context rolls back and the staged statement
remains untouched. After a successful save:

1. persist the remembered statement-account mapping;
2. remove the staged statement through `StatementIntakeStore`;
3. refresh Inbox and Spending pending counts.

If step 2 fails, report **Records saved; statement cleanup needed**. The staged
item remains visible, but exact fingerprints prevent another financial write.
The owner can retry cleanup safely.

When every row is already imported, the primary action is **Remove reviewed
statement**. It performs no SwiftData write and removes the staged item only
after explicit confirmation.

## User Experience

### Reconciliation summary

- The existing preview summary gains selected account, new transaction count,
  new transfer count, linked count, already-imported count, skipped count, and
  unresolved count.
- Incomplete parser output keeps the existing review UI but disables all commit
  controls with a clear explanation.
- The primary button says **Import N records** and is disabled while any row is
  unresolved or invalid.
- Before commit, a confirmation lists counts by transaction, transfer, link, and
  skip. It never repeats source references or notes.

### Row interaction

- Each row clearly labels one of: New, Possible duplicate, Already imported,
  Transfer, Skipped, or Needs attention.
- Tapping a row opens a focused editor rather than placing multiple pickers in
  the scrolling list.
- Candidate amount, direction, source date, reference, and page remain visible
  for comparison. Reference and note are always rendered as untrusted text.
- VoiceOver announces status independently of color. All controls retain
  44-point targets and stable content-free accessibility identifiers.

### Success and failure

- Successful import dismisses the statement, refreshes Inbox, and presents a
  concise count of records created or linked.
- Save failure leaves the editor and all owner choices visible for retry.
- Cleanup failure distinguishes saved financial records from the still-pending
  PDF and offers **Retry cleanup**.
- Reopening after an interrupted success shows exact prior imports, never a
  second set of selectable “new” rows.

## Tech Stack

- Swift 6, SwiftUI, Observation, SwiftData, and Foundation.
- Existing `TransactionDraft`, `TransferDraft`, transaction defaults, account
  and category models, parser candidates, inbox service, and App Group store.
- One lightweight optional-field SwiftData migration; no new package.
- Private CloudKit continues through the existing `ModelContainer`.
- UserDefaults stores only the local bank/suffix-to-account mapping.

## Commands

Run unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

Compile the iOS SDK without running a Simulator:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

After relevant app changes, build, install, and launch on the physical phone:

```sh
rtk scripts/run-iphone.sh Yushaku
```

## Project Structure

```text
MonMon/Imports/StatementImportReconciler.swift
    Pure matching and row-resolution state; no SwiftData writes.

MonMon/Imports/StatementImportCommitService.swift
    Revalidation, dedicated-context atomic save, defaults, and staged cleanup.

MonMon/Imports/StatementAccountMapping.swift
    Local bank/account-suffix mapping with stale-id validation.

MonMon/Imports/StatementImportPreviewView.swift
    Summary, row statuses, reconciliation editors, confirmation, and result UI.

MonMon/Transactions/MoneyTransaction.swift
MonMon/Transfers/AccountTransfer.swift
    Optional content-hash provenance fields.

MonMon/App/StoreReconciler.swift
    Deterministic folding for duplicate imported records after CloudKit sync.

MonMonTests/Imports/StatementImportReconcilerTests.swift
MonMonTests/Imports/StatementImportCommitServiceTests.swift
MonMonTests/Imports/StatementAccountMappingTests.swift
    Pure matching, in-memory persistence, idempotency, and default tests.
```

Planning may split UI files further, but it must preserve the pure reconciler
and persistence service boundary.

## Code Style

- Use explicit enums for row status and resolution; do not encode them as
  booleans such as `isDuplicate` plus `isTransfer`.
- Keep matching pure and deterministic. Pass the Vietnam calendar explicitly in
  tests rather than reading current locale or time zone.
- Keep exact amounts as `Decimal`; never compare through `Double` or formatted
  strings.
- Store only validated lowercase hashes as import ids.
- The commit service accepts ids and value types, then re-fetches models in its
  own context. Never send SwiftData model objects across actors or contexts.
- Treat source note/reference as untrusted display text. Do not interpolate it
  into logs, errors, analytics, accessibility identifiers, or confirmation text.

Example:

```swift
switch row.resolution {
case let .transaction(categoryID, note):
    // Revalidate ids and create through the existing draft boundary.
case let .newTransfer(otherAccountID, note):
    // Candidate direction determines which endpoint is the statement account.
case .linkTransaction, .linkTransfer:
    // Attach provenance only after eligibility is rechecked.
case .skip, .unresolved:
    break
}
```

## Testing Strategy

Use Swift Testing with synthetic candidates and in-memory SwiftData. No real
statement text or file enters tests.

Required pure reconciliation cases:

- valid remembered mapping preselects the account; stale/missing suffix does not;
- exact transaction and both exact transfer sides are recognized by fingerprint;
- possible transaction requires account, kind, amount, currency, and local day;
- possible transfer requires the direction-correct account side, amount,
  currency, local day, and an empty side fingerprint;
- note similarity never creates a match;
- multiple possible matches remain unresolved;
- defaults apply only to an existing category of the matching direction;
- transfer endpoints follow candidate direction and cannot be the same account;
- input order and candidate ids produce deterministic reconciliation output.

Required persistence cases:

- one commit creates the expected transactions, transfers, and provenance;
- linking updates provenance without creating another financial record;
- skipped and already-imported rows produce no write;
- any invalid row rolls back the whole financial commit;
- a repeated commit is idempotent even if staged cleanup previously failed;
- a save failure leaves the staged item and account mapping unchanged;
- cleanup failure preserves saved records and succeeds on cleanup retry;
- all-exact cleanup performs no SwiftData write;
- imported CloudKit duplicates fold deterministically without touching manual or
  recurring transactions;
- historical outgoing transfers do not use today's available-balance check.

Required UI/state cases:

- incomplete parser output cannot expose an enabled commit action;
- unresolved and ambiguous rows are visible and block commit;
- successful commit refreshes every pending-count surface;
- failure retains row choices for retry;
- accessibility identifiers use indexes or static roles, never import hashes,
  references, notes, account suffixes, or filenames.

Full existing parser, inbox, transaction, transfer, reconciliation, and CloudKit
suites remain green.

## Boundaries

### Always do

- Require a complete parsed statement and explicit statement account.
- Reconcile again immediately before writing.
- Save financial records and provenance together in one SwiftData transaction.
- Delete staged bytes only after financial save succeeds.
- Keep cleanup retry idempotent.
- Run full tests, format lint, iOS SDK build, and physical-device workflow.

### Ask first

- Change the matching fields or local-day rule.
- Add source-fact editing for amount, direction, or timestamp.
- Add automatic category or transfer inference from note text.
- Persist raw references, notes, statement metadata, or parsed sessions.
- Add bulk commit across multiple statements.
- Change post-commit retention or keep imported PDFs.

### Never do

- Auto-link a possible duplicate or possible transfer.
- Import an unresolved row or a statement with parser issues.
- Delete staged bytes before the SwiftData save succeeds.
- Treat two equal amounts alone as the same financial event.
- Upload, log, or commit statement content.
- Use a Simulator for runtime/UI acceptance unless explicitly requested.

## Success Criteria

- The owner selects the statement account once and every complete candidate is
  visibly classified as new, possible match, exact prior import, or unresolved.
- The owner can categorize an ordinary transaction, mark a transfer and select
  its other account, link an eligible existing record, or skip a row.
- No possible match is chosen automatically.
- A valid commit creates or links exactly the reviewed records in one SwiftData
  save, with source fingerprints but no raw statement provenance.
- Re-importing overlapping or previously committed statement rows cannot create
  a second record from the same candidate fingerprint.
- Internal transfers affect account balances but never income/expense totals.
- Save and cleanup failures are distinct, recoverable, and idempotent.
- Successful cleanup removes the staged statement and refreshes Inbox/Spending.
- Automated gates pass; build/install/launch succeeds on `Yushaku`; the owner
  completes hands-on import acceptance on the physical device.

## Out of Scope

- OCR, CSV, encrypted PDFs, other banks, and multiple attachments.
- Merchant normalization, learned categories, or note-based automatic transfer
  inference.
- Editing parsed amount, direction, timestamp, source reference, or page.
- Bulk reconciliation across several staged statements in one screen or commit.
- Keeping or syncing raw PDFs or parsed import sessions.
- Undo across an already-saved import; records use existing transaction/transfer
  edit and delete flows after commit.

## Open Questions

None. The owner approved the provenance migration, post-save staged cleanup,
conservative same-local-day matching, and explicit transfer classification.
