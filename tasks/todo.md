# Tasks: Transaction Import Inbox — Review Checkpoint

## Task 1: Add shared App Group configuration and inbox service

**Description:** Start with failing tests for the app-side boundary that lists
staged statements, revalidates and parses one item asynchronously, removes one
item, and reports typed failures. Add one shared App Group identifier consumed by
both the containing app and existing Share Extension.

**Acceptance criteria:**

- [ ] Live composition resolves `group.com.sonlv.monmon.local.yushaku` through
      `FileManager.containerURL` and reports `.appGroupUnavailable` safely.
- [ ] Pending statements preserve `StatementIntakeStore` ordering and metadata.
- [ ] Preview passes only store-validated bytes to `BankStatementParsing` and
      returns the selected manifest with the unchanged parsed result.
- [ ] Removing one item is idempotent and does not affect siblings.
- [ ] The Share Extension uses the shared identifier and otherwise keeps its
      already-verified staging behavior.

**Verification:**

- [ ] New `StatementImportInboxServiceTests` fail before implementation.
- [ ] Focused service, parser, and intake-store tests pass afterward.
- [ ] Containing app and Share Extension targets compile.

**Dependencies:** Approved spec

**Files likely touched:**

- `MonMon/Imports/StatementImportInboxService.swift`
- `MonMon/Imports/StatementIntakeStore.swift`
- `MonMonShareExtension/ShareViewController.swift`
- `MonMonTests/Imports/StatementImportInboxServiceTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, one service seam plus target wiring

## Checkpoint: Service

- [ ] Listing, preview, removal, and failure contracts pass focused tests.
- [ ] Service code imports no SwiftUI or SwiftData.
- [ ] No production/test diagnostic includes PDF text, path, hash, or reference.

## Task 2: Add observable inbox state with stale-result protection

**Description:** Start with failing state tests, then add the smallest
main-actor observable model that drives list and preview phases, refreshes after
removal, maps typed failures to safe presentation values, and discards a parse
result when selection has changed.

**Acceptance criteria:**

- [ ] List state distinguishes idle/loading/loaded/failed, including a real
      loaded-empty state.
- [ ] Preview state distinguishes loading/loaded/failed for one staged id.
- [ ] Retry leaves the staged item intact.
- [ ] Successful removal refreshes pending state and clears only the matching
      selection.
- [ ] An older async result cannot overwrite the currently selected preview.

**Verification:**

- [ ] New state tests fail before implementation.
- [ ] Focused state and service tests pass after every behavior increment.
- [ ] Swift concurrency checks pass under the project's Swift 6 settings.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/Imports/StatementImportInbox.swift`
- `MonMonTests/Imports/StatementImportInboxTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium, one state model and one suite

## Checkpoint: State

- [ ] Phase transitions and safe errors are deterministic.
- [ ] State logic has no direct filesystem, entitlement, PDFKit, or SwiftData use.
- [ ] Viewing and failure paths never call removal.

## Task 3: Build the inbox list and parsed preview screens

**Description:** Build SwiftUI screens on top of the tested state model. The
list shows safe staged metadata and explicit loading/empty/error states. The
preview shows statement summary, issues, candidate rows, retry, and confirmed
removal, but no commit control.

**Acceptance criteria:**

- [ ] Inbox rows show filename, received date, and formatted byte size without
      showing content ids or paths.
- [ ] Empty state explains how to export and Share a PDF to MonMon.
- [ ] Preview shows bank, masked account suffix, period, completeness, candidate
      count, income/expense totals, notes, references, dates, direction, and page.
- [ ] Issues and parse failures are visible through icon/text, not color alone.
- [ ] Remove Statement is destructive, confirmed, and returns to the refreshed
      list only after successful removal.
- [ ] Controls meet 44-point targets and have stable accessibility identifiers.

**Verification:**

- [ ] iOS SDK compile succeeds after adding both screens.
- [ ] Light/dark and English/Vietnamese strings compile with no missing catalogue
      entries introduced by the task.
- [ ] Code inspection confirms there is no SwiftData environment or commit path.

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

- [ ] Toolbar opens Import Inbox when zero or more items exist.
- [ ] A non-zero pending count produces a prominent one-tap banner above the
      spending overview.
- [ ] Returning to MonMon after sharing refreshes without relaunching the app.
- [ ] Lookup failure is visible and cannot masquerade as an empty inbox.
- [ ] Closing the inbox after removal updates both toolbar accessibility text
      and banner state.

**Verification:**

- [ ] Transaction list and import unit suites pass.
- [ ] iOS SDK build passes without a Simulator runtime.
- [ ] Accessibility identifiers cover toolbar, banner, inbox, rows, retry, and
      removal confirmation.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/Transactions/TransactionListView.swift`
- `MonMon/Resources/Localizable.xcstrings`
- `MonMonTests/Imports/StatementImportInboxTests.swift`

**Estimated scope:** Small, one integration point

## Checkpoint: UI

- [ ] One pending statement is visible from Spending after foreground refresh.
- [ ] Selecting it reaches parsed review or a safe retryable failure.
- [ ] Confirmed removal refreshes every pending-state surface.
- [ ] No Import, Save, Commit, account, category, duplicate, or transfer UI exists.

## Task 5: Clear gates and deploy to Yushaku

**Description:** Run the repository quality gates, inspect the diff for scope and
privacy regressions, then build, install, and launch on the connected physical
iPhone. Hand the actual inbox interaction to the owner.

**Acceptance criteria:**

- [ ] Full macOS tests pass.
- [ ] Recursive Swift format lint passes.
- [ ] Compile-only iOS SDK build passes.
- [ ] Physical build, install, and launch succeed on `Yushaku`.
- [ ] Git diff contains no real PDF, extracted data, local path, content hash,
      derived output, or unrelated edits.

**Verification:**

- [ ] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- [ ] `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- [ ] `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedDataIOS CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build`
- [ ] `rtk scripts/run-iphone.sh Yushaku`

**Dependencies:** Task 4

**Files likely touched:**

- `SPEC-transaction-import-inbox.md` only if implementation reveals an approved
  requirement change
- `tasks/plan.md`
- `tasks/todo.md`

**Estimated scope:** Small, verification and documentation only

## Checkpoint: Complete

- [ ] Approved spec and plan success criteria are met.
- [ ] Definition of Done is satisfied.
- [ ] Owner reviews the inbox checkpoint on `Yushaku` before work begins on
      `import-reconciliation` and transaction commit.
