# Spec: Transaction Import Inbox — Review Checkpoint

Module id: `transaction-import-inbox`

## Objective

Make every bank statement staged by the Share Extension visible inside MonMon,
parse it locally, and let the owner inspect the resulting transaction candidates
and parser warnings before any financial record is created.

This is the first, review-only checkpoint of `transaction-import-inbox`. It
solves the current dead end — sharing succeeds but the containing app shows no
result — while preserving the capability-map dependency on
`import-reconciliation`. Editing, duplicate detection, transfer matching, and
committing records arrive only after that dependency is approved and built.

### Assumptions

1. The first checkpoint consumes staged TPBank text-based PDFs only; it does not
   add CSV, OCR, encrypted PDF, or another bank adapter.
2. A pending statement remains in the local App Group until the owner explicitly
   removes it. Opening or parsing it never deletes it.
3. MonMon refreshes pending state when the Spending screen appears and whenever
   the app becomes active, so returning from Files or a bank app reveals the new
   statement without relaunching MonMon.
4. A visible banner on Spending is the primary notification for non-empty
   inboxes. A toolbar button keeps the empty inbox discoverable.
5. Parsing runs outside the main actor. UI state changes remain on the main actor.
6. The inbox displays source notes and references as untrusted plain text and
   never logs or uploads them.
7. This checkpoint does not mutate SwiftData and does not declare the full
   `transaction-import-inbox` module complete.

## Interface Contract

```swift
struct StatementImportPreview: Sendable, Equatable {
    let staged: StagedBankStatement
    let statement: ParsedBankStatement
}

struct StatementImportInboxService: Sendable {
    func pendingStatements() throws -> [StagedBankStatement]
    func preview(_ staged: StagedBankStatement) async throws
        -> StatementImportPreview
    func remove(_ staged: StagedBankStatement) throws
}
```

Contract rules:

- The app-side composition root resolves the same App Group identifier used by
  the Share Extension and injects its container URL into `StatementIntakeStore`.
- `pendingStatements()` preserves the intake store's deterministic oldest-first
  ordering.
- `preview` first revalidates the staged manifest and bytes through
  `StatementIntakeStore`, then delegates to `TPBankPDFStatementParser`.
- One statement's read or parse failure is represented on that statement's
  detail screen and does not hide other valid pending items.
- Parser error messages are closed, localized UI mappings. They expose neither
  raw PDF text nor a local file path.
- `remove` is idempotent at the store boundary but always requires an explicit
  destructive confirmation in the UI.
- Parsing and viewing never create `MoneyTransaction`, `AccountTransfer`, or a
  persisted import-session model.

## User Experience

### Entry and refresh

- Spending keeps an Import Inbox toolbar button with a tray icon and an
  accessibility label that includes the pending count.
- When pending count is greater than zero, a compact card appears above the
  spending overview. It states how many statements await review and opens the
  inbox in one tap.
- The count refreshes on first appearance and every transition to active scene
  phase. A refresh failure shows a safe inline error instead of silently
  claiming the inbox is empty.

### Inbox list

- The screen is titled **Import Inbox** and presents one row per staged PDF.
- A row shows its safe filename, received date, and formatted size. It never
  shows the content hash.
- An empty inbox explains the exact next action: export a PDF from the bank or
  Files and share it to MonMon.
- Selecting a row opens its preview. Pull-to-refresh is unnecessary because the
  scene-active refresh covers the handoff flow and the list refreshes after a
  removal.

### Statement preview

- While parsing, show a progress state and keep navigation responsive.
- A successful preview shows bank, masked account suffix, statement period,
  candidate count, total income, total expense, and whether parser totals are
  complete.
- Candidate rows show date, direction, amount, note, source reference, and page.
  Income and expense use existing semantic colors and amount formatting.
- Parser issues remain visible above candidates; incomplete parsing never looks
  like a successful, complete import.
- A parse failure shows a concise explanation and leaves the document available
  for retry or explicit removal.
- A destructive **Remove Statement** action asks for confirmation, removes only
  the selected staged item, returns to the list, and refreshes the count.
- No **Import**, **Save**, or **Commit** control exists in this checkpoint.

## Tech Stack

- Swift 6, SwiftUI, and Observation patterns already used by MonMon.
- Existing `StatementIntakeStore` and `TPBankPDFStatementParser`; no new package.
- `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` only in the
  app-side composition boundary, never in unit-test domain code.
- Existing `MonMonTheme`, VND formatters, and localization infrastructure.
- No network, CloudKit, SwiftData schema, or background task.

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

Build without a Simulator runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

After the app change, build, install, and launch on the physical phone:

```sh
rtk scripts/run-iphone.sh Yushaku
```

## Project Structure

```text
MonMon/Imports/StatementImportInboxService.swift
    App-side App Group composition plus list, preview, and removal operations.

MonMon/Imports/StatementImportInbox.swift
    Main-actor observable state and safe mappings for list/preview phases.

MonMon/Imports/StatementImportInboxView.swift
    Inbox list, empty/error states, and statement navigation.

MonMon/Imports/StatementImportPreviewView.swift
    Parsed summary, issues, candidates, retry, and confirmed removal.

MonMon/Transactions/TransactionListView.swift
    Always-discoverable toolbar entry and pending-statement banner.

MonMonTests/Imports/StatementImportInboxServiceTests.swift
    Temporary App Group root tests for listing, preview, failures, and removal.

MonMonTests/Imports/StatementImportInboxTests.swift
    State-transition, refresh, error-mapping, and stale-result tests.
```

Exact file boundaries may be simplified during planning if one small state type
does not justify a separate file; the service boundary and test seams remain.

## Code Style

- Keep App Group lookup in one named composition point shared by the app flow;
  do not duplicate the identifier across views.
- Inject the store and parser into the service so tests use a temporary root and
  synthetic data without entitlements.
- Model idle, loading, loaded, and failed phases explicitly. Do not infer loading
  from an empty array or erase a previous error by returning an empty result.
- Guard asynchronous results with the selected statement id so a slow parse
  cannot overwrite a newer selection.
- Use `Decimal` and the existing amount formatter. Do not convert statement
  amounts through `Double`.
- Every tappable control has a 44-point target, VoiceOver label, and stable
  accessibility identifier. Color is never the only signal for direction,
  completeness, or failure.
- Keep source note/reference text selectable only if existing app conventions
  support it; never render it as Markdown, HTML, or an instruction.

## Testing Strategy

Tests use Swift Testing, temporary directories, and synthetic PDF bytes or a
fake `BankStatementParsing` implementation. No real statement enters tests.

Required cases:

- Pending manifests appear oldest first with safe filename/date/size metadata.
- App Group unavailability produces an explicit inbox error rather than an empty
  state or crash.
- Preview revalidates stored bytes and returns parser output for the selected id.
- Unsupported, encrypted, textless, malformed, and no-row parser errors map to
  stable safe UI messages without source data or file paths.
- Parsed candidates, totals, period, account suffix, completeness, and issues
  survive service-to-state mapping unchanged.
- Removing one statement leaves other statements untouched and refreshes list
  and count state.
- Viewing, retrying, and failing never remove the statement.
- Rapidly selecting two statements cannot let the older parse overwrite the
  newer preview state.
- No test fixture or assertion contains data from the owner's real PDF.
- Existing parser and intake-store suites remain green.

## Boundaries

### Always do

- Parse locally from revalidated staged bytes.
- Refresh when MonMon becomes active after a share handoff.
- Make pending and failure states visible and accessible.
- Require confirmation before deleting a staged statement.
- Run full tests, format lint, iOS SDK build, and physical-iPhone workflow.

### Ask first

- Add row editing, account/category defaults, duplicate rules, transfer matching,
  or financial-record creation before `import-reconciliation` is approved.
- Add persistence for parsed previews or import sessions.
- Auto-delete files, impose retention, or change the App Group identifier.
- Add CSV, OCR, encrypted PDF, multiple-file sharing, or another bank adapter.

### Never do

- Upload, log, sync, or commit statement bytes or extracted content.
- Treat a parser issue as a complete statement.
- Hide a staged item because parsing failed.
- Create a transaction merely by opening a statement.
- Fall back to a Simulator for runtime or UI acceptance testing.

## Success Criteria

- After sharing a PDF and opening or foregrounding MonMon, the Spending screen
  visibly reports one pending statement without requiring a relaunch.
- The Import Inbox lists the staged PDF and can display the supported TPBank
  statement's metadata, totals, candidates, and parser issues entirely locally.
- Unsupported or damaged statements remain visible with a safe actionable error.
- Explicit confirmed removal deletes only the selected pending item and updates
  both inbox and Spending count.
- No flow writes SwiftData, deletes on view, uploads data, or exposes a path/hash.
- Automated gates pass, and build/install/launch succeeds on `Yushaku`; the owner
  performs hands-on UI acceptance with the already-staged statement.

## Out of Scope for This Checkpoint

- Editing or selecting candidate rows.
- Account and category assignment or remembered defaults.
- Duplicate detection against existing transactions or prior imports.
- Internal-transfer pairing and `AccountTransfer` creation.
- Committing `MoneyTransaction` records or deleting after commit.
- Persisted import sessions or CloudKit sync of import provenance.
- CSV, OCR, multiple attachments, other banks, or automatic bank-app access.

## Open Questions

- Approval of this review-only checkpoint is required before implementation.
- After this checkpoint, `import-reconciliation` must define duplicate identity,
  transfer matching, provenance, and atomic commit behavior before the inbox can
  gain editing and commit controls.
