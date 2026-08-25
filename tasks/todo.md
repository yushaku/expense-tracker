# Tasks: Transaction Import Inbox — Review Checkpoint

## Task 1: Add shared App Group configuration and inbox service

**Description:** Start with failing tests for the app-side boundary that lists
staged statements, revalidates and parses one item asynchronously, removes one
item, and reports typed failures. Add one shared App Group identifier consumed by
both the containing app and existing Share Extension.

**Acceptance criteria:**

- [x] Live composition resolves `group.com.sonlv.monmon.local.yushaku` through
      `FileManager.containerURL` and reports `.appGroupUnavailable` safely.
- [x] Pending statements preserve `StatementIntakeStore` ordering and metadata.
- [x] Preview passes only store-validated bytes to `BankStatementParsing` and
      returns the selected manifest with the unchanged parsed result.
- [x] Removing one item is idempotent and does not affect siblings.
- [x] The Share Extension uses the shared identifier and otherwise keeps its
      already-verified staging behavior.

**Verification:**

- [x] New `StatementImportInboxServiceTests` fail before implementation.
- [x] Focused service, parser, and intake-store tests pass afterward.
- [x] Containing app and Share Extension targets compile.

**Dependencies:** Approved spec

**Files likely touched:**

- `MonMon/Imports/StatementImportInboxService.swift`
- `MonMon/Imports/StatementIntakeStore.swift`
- `MonMonShareExtension/ShareViewController.swift`
- `MonMonTests/Imports/StatementImportInboxServiceTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, one service seam plus target wiring

## Checkpoint: Service

- [x] Listing, preview, removal, and failure contracts pass focused tests.
- [x] Service code imports no SwiftUI or SwiftData.
- [x] No production/test diagnostic includes PDF text, path, hash, or reference.

## Task 2: Add observable inbox state with stale-result protection

**Description:** Start with failing state tests, then add the smallest
main-actor observable model that drives list and preview phases, refreshes after
removal, maps typed failures to safe presentation values, and discards a parse
result when selection has changed.

**Acceptance criteria:**

- [x] List state distinguishes idle/loading/loaded/failed, including a real
      loaded-empty state.
- [x] Preview state distinguishes loading/loaded/failed for one staged id.
- [x] Retry leaves the staged item intact.
- [x] Successful removal refreshes pending state and clears only the matching
      selection.
- [x] An older async result cannot overwrite the currently selected preview.

**Verification:**

- [x] New state tests fail before implementation.
- [x] Focused state and service tests pass after every behavior increment.
- [x] Swift concurrency checks pass under the project's Swift 6 settings.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/Imports/StatementImportInbox.swift`
- `MonMonTests/Imports/StatementImportInboxTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, one state model and one suite

## Checkpoint: State

- [x] Phase transitions and safe errors are deterministic.
- [x] State logic has no direct filesystem, entitlement, PDFKit, or SwiftData use.
- [x] Viewing and failure paths never call removal.

## Task 3: Build the inbox list and parsed preview screens

**Description:** Build SwiftUI screens on top of the tested state model. The
list shows safe staged metadata and explicit loading/empty/error states. The
preview shows statement summary, issues, candidate rows, retry, and confirmed
removal, but no commit control.

**Acceptance criteria:**

- [x] Inbox rows show filename, received date, and formatted byte size without
      showing content ids or paths.
- [x] Empty state explains how to export and Share a PDF to MonMon.
- [x] Preview shows bank, masked account suffix, period, completeness, candidate
      count, income/expense totals, notes, references, dates, direction, and page.
- [x] Issues and parse failures are visible through icon/text, not color alone.
- [x] Remove Statement is destructive, confirmed, and returns to the refreshed
      list only after successful removal.
- [x] Controls meet 44-point targets and have stable accessibility identifiers.

**Verification:**

- [x] iOS SDK compile succeeds after adding both screens.
- [x] Light/dark and English/Vietnamese strings compile with no missing catalogue
      entries introduced by the task.
- [x] Code inspection confirms there is no SwiftData environment or commit path.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMon/Imports/StatementImportInboxView.swift`
- `MonMon/Imports/StatementImportPreviewView.swift`
- `MonMon/Resources/Localizable.xcstrings`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, two focused screens

## Task 4: Integrate Import Inbox into Spending and foreground refresh

**Description:** Add an always-discoverable toolbar entry and a conditional
pending banner to `TransactionListView`. Present the inbox as a sheet, refresh
on first appearance and active scene phase, and propagate list/removal updates
back to the pending count.

**Acceptance criteria:**

- [x] Toolbar opens Import Inbox when zero or more items exist.
- [x] A non-zero pending count produces a prominent one-tap banner above the
      spending overview.
- [x] Returning to MonMon after sharing refreshes without relaunching the app.
- [x] Lookup failure is visible and cannot masquerade as an empty inbox.
- [x] Closing the inbox after removal updates both toolbar accessibility text
      and banner state.

**Verification:**

- [x] Transaction list and import unit suites pass.
- [x] iOS SDK build passes without a Simulator runtime.
- [x] Accessibility identifiers cover toolbar, banner, inbox, rows, retry, and
      removal confirmation.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/Transactions/TransactionListView.swift`
- `MonMon/Resources/Localizable.xcstrings`
- `MonMonTests/Imports/StatementImportInboxTests.swift`

**Estimated scope:** Small, one integration point

## Checkpoint: UI

- [x] One pending statement is visible from Spending after foreground refresh.
- [x] Selecting it reaches parsed review or a safe retryable failure.
- [x] Confirmed removal refreshes every pending-state surface.
- [x] No Import, Save, Commit, account, category, duplicate, or transfer UI exists.

## Task 5: Clear gates and deploy to Yushaku

**Description:** Run the repository quality gates, inspect the diff for scope and
privacy regressions, then build, install, and launch on the connected physical
iPhone. Hand the actual inbox interaction to the owner.

**Acceptance criteria:**

- [x] Full macOS tests pass.
- [x] Recursive Swift format lint passes.
- [x] Compile-only iOS SDK build passes.
- [x] Physical build, install, and launch succeed on `Yushaku`.
- [x] Footer-only final pages, running Balance columns, and transactions without
      a time component pass synthetic parser regressions.
- [x] Git diff contains no real PDF, extracted data, local path, content hash,
      derived output, or unrelated edits.

**Verification:**

- [x] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- [x] `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- [x] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- [x] `rtk scripts/run-iphone.sh Yushaku`

**Dependencies:** Task 4

**Files likely touched:**

- `SPEC-transaction-import-inbox.md` only if implementation reveals an approved
  requirement change
- `tasks/plan.md`
- `tasks/todo.md`

**Estimated scope:** Small, verification and documentation only

## Checkpoint: Complete

- [x] Approved spec and plan success criteria are met.
- [x] Definition of Done is satisfied.
- [x] Owner reviews the inbox checkpoint on `Yushaku` before work begins on
      `import-reconciliation` and transaction commit.
