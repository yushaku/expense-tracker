# Task List: cash-balance

**Status:** Automated implementation complete; awaiting owner verification (2026-08-23)  
**Spec:** `SPEC-cash-balance.md`  
**Plan:** `tasks/plan.md`

Complete tasks in order. Record red/green evidence before checking off each TDD
task. Do not start implementation until the owner approves this checklist.

## Command Reference

Focused work may run only the relevant test, but each green task runs the full
macOS test target because the project is still small:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Debug compile checks:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Formatting check:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests
```

## Task 1: Define the persistence contract in a failing test

**Description:** Add the first Swift Testing contract for a cash account before
any production model exists. The intended red state must fail only because the
approved SwiftData types are missing.

**Acceptance criteria:**

- [x] The test constructs a cash account with fixed UUID, date, kind, exact
  `Decimal` opening balance, and VND currency code.
- [x] The test inserts, saves, and fetches through an in-memory
  `ModelContainer`, then compares every persisted field.
- [x] The initial test command fails for the expected missing-model contract,
  not a broken project reference or unrelated bootstrap error.

**Verification:**

- [x] Run the macOS test command and record the exact intended compiler/test
  failure.
- [x] `rtk git diff --check` passes for the test and project changes.

**Dependencies:** None

**Files likely touched:**

- `MonMonTests/Accounts/CashAccountPersistenceTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Small (2 files)

**Evidence:** The macOS test build reached
`CashAccountPersistenceTests.swift` and failed with `Cannot find 'CashAccount'
in scope` plus the expected unresolved `.bank` references. `plutil` validated
the updated project, the focused strict-format lint passed, and
`git diff --check` returned clean (2026-08-23).

## Task 2: Implement the persisted cash-account model

**Description:** Make Task 1 green with the smallest SwiftData model and install
the production model container at the app root.

**Acceptance criteria:**

- [x] `CashAccountKind` and `CashAccount` match the approved data contract and
  preserve `Decimal` exactly in an in-memory save/fetch round trip.
- [x] `MonMonApp` provides a local `ModelContainer` containing `CashAccount` and
  adds no CloudKit configuration.
- [x] No repository, service layer, migration plan, or third-party dependency is
  introduced.

**Verification:**

- [x] The macOS test command passes, including the new persistence test.
- [x] Both Debug compile commands and the formatting check pass.

**Dependencies:** Task 1

**Files likely touched:**

- `MonMon/Accounts/CashAccountKind.swift`
- `MonMon/Accounts/CashAccount.swift`
- `MonMon/App/MonMonApp.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium (4 files)

**Evidence:** Outside the restricted sandbox, the full macOS Swift Testing target
passed and the in-memory round trip preserved every field, including the exact
`Decimal`. macOS Debug and the approved `-sdk iphonesimulator` Debug command
exited 0; because the iOS platform component has no eligible generic destination,
an additional direct Swift compiler check targeting
`arm64-apple-ios18.0-simulator` type-checked all app sources successfully. Strict
formatting and project plist validation passed. No CloudKit configuration or new
dependency was added (2026-08-23).

## Task 3: Define VND validation in failing tests

**Description:** Specify the complete account-draft input boundary before its
implementation, using fixed inputs and no system locale or clock dependency.

**Acceptance criteria:**

- [x] Tests cover trimmed and empty names plus cash/bank kind preservation.
- [x] Tests cover zero, positive ungrouped, Vietnamese-grouped, nonnumeric, and
  negative balances with the exact typed error expected.
- [x] The initial test command fails only because the draft/formatter contract is
  not implemented.

**Verification:**

- [x] Run the macOS test command and record the exact intended red-state failure.
- [x] `rtk git diff --check` passes for the test and project changes.

**Dependencies:** Task 2

**Files likely touched:**

- `MonMonTests/Accounts/AccountDraftTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Small (2 files)

**Evidence:** The macOS test build reached `AccountDraftTests.swift` and failed
only on the intentionally absent `AccountDraft`, `AccountFormError`, and
`VNDCurrency` contracts. The existing app/model target compiled first. The new
test's strict-format lint, project plist validation, and `git diff --check` all
passed (2026-08-23).

## Task 4: Implement deterministic VND validation and formatting

**Description:** Make Task 3 green with a value-type draft and one focused VND
utility. Parsing and display must use an explicit Vietnamese locale.

**Acceptance criteria:**

- [x] Successful validation returns a trimmed name, selected kind, exact
  nonnegative `Decimal`, `VND`, and caller-supplied identity/date values.
- [x] Empty, nonnumeric, and negative inputs return their approved typed errors
  without creating a SwiftData model.
- [x] VND display uses locale-aware grouping and zero fractional digits without
  consulting the device's current locale.

**Verification:**

- [x] The macOS test command passes, including every draft and formatting case.
- [x] Both Debug compile commands and the formatting check pass.

**Dependencies:** Task 3

**Files likely touched:**

- `MonMon/Accounts/AccountDraft.swift`
- `MonMon/Accounts/VNDCurrency.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium (3 files)

**Evidence:** All seven draft/format tests passed: trimmed values, cash/bank kind,
zero, ungrouped and Vietnamese-grouped amounts, nonnumeric and negative errors,
and localized VND display. The first GREEN run exposed a duplicate hand-authored
project reference ID; assigning `VNDCurrency.swift` a unique ID removed the
malformed-project warning and made the suite pass. macOS Debug, the approved iOS
SDK command, strict formatting, and direct
`arm64-apple-ios18.0-simulator` type-check all exited 0 (2026-08-23).

## Checkpoint A: Data foundation

- [x] Tasks 1–4 contain recorded red/green evidence.
- [x] SwiftData round-trip preserves all approved fields and exact money values.
- [x] Validation and VND formatting are deterministic under tests.
- [x] macOS and iOS Simulator SDK Debug builds pass.
- [x] No UI beyond the bootstrap screen has changed yet.

## Task 5: Define total calculation in failing tests

**Description:** Specify the pure combined-balance behavior before connecting
SwiftData results to the visible list.

**Acceptance criteria:**

- [x] Tests cover empty, one-account, and multiple-account totals.
- [x] Tests use exact `Decimal` values and include both cash and bank kinds.
- [x] The initial test command fails only because `CashBalanceSummary` is absent.

**Verification:**

- [x] Run the macOS test command and record the exact intended red-state failure.
- [x] `rtk git diff --check` passes for the test and project changes.

**Dependencies:** Checkpoint A

**Files likely touched:**

- `MonMonTests/Accounts/CashBalanceSummaryTests.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Small (2 files)

**Evidence:** The full macOS test build compiled the existing app/model code and
failed only in `CashBalanceSummaryTests.swift` with three expected `Cannot find
'CashBalanceSummary' in scope` errors. Focused strict formatting, project plist
validation, and `git diff --check` passed (2026-08-23).

## Task 6: Render query-backed cash balances

**Description:** Make Task 5 green and replace the bootstrap greeting with a
shared SwiftUI screen that reads locally persisted accounts.

**Acceptance criteria:**

- [x] `CashBalanceSummary` returns the exact tested totals and
  `AccountListView` queries accounts ordered by creation date.
- [x] The empty state is understandable; the populated state displays total
  first and then each account's name, kind, and formatted VND balance.
- [x] `ContentView` hosts the feature root and the list exposes the approved
  `account-list` accessibility identifier on both platforms.

**Verification:**

- [x] The macOS test command passes, including total-calculation tests.
- [x] Both Debug compile commands and the formatting check pass.

**Dependencies:** Task 5

**Files likely touched:**

- `MonMon/Accounts/CashBalanceSummary.swift`
- `MonMon/Accounts/AccountListView.swift`
- `MonMon/App/ContentView.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium (4 files)

**Evidence:** The three total tests passed with exact `Decimal` results. The
query-backed view compiles with forward `createdAt` sorting, native empty/list
states, total-first sections, formatted rows, and `account-list`. Full macOS
tests, macOS Debug, the approved iOS SDK command, strict formatting, and direct
`arm64-apple-ios18.0-simulator` type-check passed (2026-08-23).

## Task 7: Complete the add-account flow

**Description:** Add the single write path so the owner can open a shared form,
validate input, save an account, and see the query-backed total update.

**Acceptance criteria:**

- [x] The approved Add action and form controls exist with stable accessibility
  identifiers, Cancel behavior, and inline validation errors.
- [x] Valid input inserts and explicitly saves before dismissal; the account list
  and total update through SwiftData `@Query`.
- [x] A save error rolls back the failed insert, keeps the draft visible, shows a
  general error, and does not dismiss the sheet.

**Verification:**

- [x] The macOS test command, both Debug compile commands, and formatting pass.
- [x] Code inspection traces valid, validation-error, and save-error paths and
  confirms no dead Add action or pending failed row remains.

**Dependencies:** Task 6

**Files likely touched:**

- `MonMon/Accounts/AddAccountView.swift`
- `MonMon/Accounts/AccountListView.swift`
- `MonMon.xcodeproj/project.pbxproj`

**Estimated scope:** Medium (3 files)

**Evidence:** The shared form exposes stable identifiers for Add, name, kind,
opening balance, Cancel, Save, and error messages. Inspection confirms typed
validation returns before insertion; valid input inserts, explicitly saves, and
only then dismisses; a thrown save rolls back the pending insert and leaves the
unchanged draft plus a general error visible. SwiftData `@Query` remains the only
list/total source. The full macOS test target, macOS Debug build, approved iOS
SDK command, strict formatting, and direct
`arm64-apple-ios18.0-simulator` type-check all exited 0. The SDK command still
reports the host's known destination fallback, so the direct compiler check is
the authoritative iOS source-compatibility evidence (2026-08-23).

## Checkpoint B: Complete vertical flow

- [x] Tasks 5–7 contain recorded red/green or inspection evidence.
- [x] All automated tests and strict formatting pass.
- [x] macOS and iOS Simulator SDK Debug builds pass without project compiler
  warnings.
- [x] The complete add/list/total path is ready for owner-run UI testing.
- [x] No edit, delete, iCloud, network, market-data, AI, or MCP behavior exists.

## Task 8: Run the final quality gate and prepare handoff

**Description:** Remove obsolete bootstrap-only greeting artifacts, run every
approved automated gate, update only necessary documentation, and hand the
feature to the owner for runtime evaluation.

**Acceptance criteria:**

- [x] Obsolete greeting-only production/test code is removed without weakening
  cash-balance coverage or the shared scheme.
- [x] Debug and Release builds pass for macOS and the iOS Simulator SDK; the full
  macOS test target and strict formatting pass without feature compiler warnings.
- [x] Documentation and checklist evidence accurately describe the runnable
  feature and preserve the owner-managed UI testing boundary.

**Verification:**

- [x] Run every command in `SPEC-cash-balance.md` and record exit status plus any
  host-environment diagnostics separately from project warnings.
- [x] `rtk git status --short` contains only intended source, test, project, and
  documentation changes; no build products or user Xcode state appear.
- [x] Targeted staged-diff review finds no credentials, API keys, account numbers,
  secrets, unrelated refactors, or out-of-scope behavior.

**Dependencies:** Checkpoint B

**Files likely touched:**

- `MonMon/App/AppCopy.swift` (remove)
- `MonMonTests/AppSmokeTests.swift` (remove)
- `MonMon.xcodeproj/project.pbxproj`
- `README.md`
- `tasks/todo.md`

**Estimated scope:** Medium (5 files)

**Evidence:** The obsolete greeting constant and greeting-only smoke test were
removed from disk and the project while all finance-focused tests remained.
macOS Debug and Release builds, both approved iOS SDK commands, and the full
macOS test target exited 0. Strict formatting, project plist validation, direct
`arm64-apple-ios18.0-simulator` type-check with warnings as errors, and diff
checks also exited 0. The host still makes the SDK-only commands select macOS
because no iOS platform runtime is installed; the direct iOS compiler invocation
therefore provides the authoritative iOS source check. Xcode's code-signing-off
test copies report that bundled XCTest frameworks are already signed, and
Release metadata extraction reports no AppIntents dependency; neither diagnostic
originates in MonMon source. README now describes the runnable local feature and
owner testing boundary. Final status/diff inspection contains only intended files
and no secret-like values, build outputs, or Xcode user state (2026-08-23).

## Checkpoint C: cash-balance complete

Automated implementation gate:

- [x] Every task acceptance criterion and implementation-owned verification is
  checked with evidence.
- [x] Every success criterion in `SPEC-cash-balance.md` is met except the explicit
  owner-run checks below.
- [x] The branch contains small verified commits aligned with the approved slices.

Owner-run gate:

- [ ] Empty state and Add Account presentation feel correct on a chosen device.
- [ ] Valid and invalid submissions behave clearly.
- [ ] Accounts survive relaunch on the same device.
- [ ] iPhone keyboard/Dynamic Type and Mac window resizing remain usable.
- [ ] The owner accepts `cash-balance` before planning `income-expense`.
