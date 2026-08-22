# Implementation Plan: cash-balance

**Status:** Approved (2026-08-23)  
**Spec:** `SPEC-cash-balance.md` (approved 2026-08-23)

## Overview

Replace the bootstrap greeting with the smallest complete cash-account workflow:
persist exact VND opening balances locally, show an empty or populated account
list with a combined total, and add new cash or bank accounts through one shared
SwiftUI form. Implementation proceeds in test-first increments and stops after
the owner can evaluate this feature on iPhone and Mac.

## Architecture Decisions

- Use one SwiftData `@Model` for `CashAccount` and install its `ModelContainer`
  at the app root. No repository layer is added because this slice has one local
  store and one write path.
- Persist `Decimal` balances and a `String`-backed `Codable` account-kind enum.
  Verify this model immediately with an in-memory container before building UI.
- Keep parsing and validation in the value-type `AccountDraft`. Use an explicit
  Vietnamese locale for parsing and VND formatting so behavior does not depend
  on the device's current locale.
- Use `@Query` in `AccountListView` for live ordered results. Compute the total
  through a pure `CashBalanceSummary` helper that is independently testable.
- Insert and explicitly save from `AddAccountView`. If save fails, roll back the
  failed insert, keep the draft visible, and show a general save error.
- Share the same SwiftUI views on iPhone and Mac. The owner handles hands-on UI
  and relaunch testing; automated work covers logic, persistence, formatting,
  and both platform builds.

## Dependency Graph

```text
SwiftData model contract
  -> deterministic VND validation and formatting
    -> query-backed empty/list/total screen
      -> add-account form and save path
        -> full verification and owner handoff
```

The sequence is intentional. Each later slice consumes contracts proven by the
previous slice, and the riskiest framework compatibility is tested first.

## Implementation Slices

### Slice 1: Prove the persisted cash-account model

- Write a failing in-memory persistence test for identity, account kind, exact
  `Decimal` balance, currency code, creation date, save, and fetch.
- Add `CashAccountKind`, the SwiftData `CashAccount` model, project references,
  and the app-level model container.
- Make the focused persistence test and macOS Debug build pass.

### Slice 2: Prove deterministic VND input

- Write failing tests for trimmed names, empty names, zero/positive balances,
  Vietnamese grouping separators, nonnumeric input, and negative input.
- Implement `AccountDraft` validation plus VND parsing/formatting without reading
  the machine's current locale.
- Keep all money values as `Decimal` from successful parsing onward.

### Checkpoint A: Data foundation

- SwiftData round-trip preserves the exact approved model fields.
- Validation and VND formatting tests pass.
- macOS Debug and generic iOS Simulator Debug builds pass.
- No UI or behavior outside `cash-balance` has been introduced.

### Slice 3: Show empty and populated cash balances

- Write failing total-calculation tests for zero, one, and multiple accounts.
- Add `CashBalanceSummary` and a query-backed `AccountListView` with the approved
  empty state, total-first layout, ordered rows, VND formatting, and stable
  accessibility identifiers.
- Replace the bootstrap greeting in `ContentView` with the feature root while
  retaining one shared implementation for both platforms.

### Slice 4: Complete the add-account save path

- Add the shared Add Account sheet with name, kind, opening-balance, Cancel, and
  Save controls.
- Connect `AccountDraft` validation to inline errors and insert only valid data.
- Explicitly save before dismissing; on failure, keep the form data visible,
  roll back the failed insert, and show the save error.
- Verify the query-backed list and total update after a successful save through
  focused logic/persistence tests and compilation.

### Checkpoint B: Complete vertical flow

- All unit and in-memory persistence tests pass.
- macOS and generic iOS Simulator Debug builds pass.
- Strict Swift formatting passes.
- Code inspection confirms the form does not dismiss or retain a pending row
  after a failed save.
- Stop if any acceptance criterion would require editing, deletion, iCloud, or a
  new dependency.

### Slice 5: Quality gate and owner handoff

- Run macOS and iOS Simulator SDK builds in Debug and Release.
- Run the full macOS test suite, strict formatting, repository-hygiene, and
  compiler-warning checks.
- Update project documentation only where the runnable app behavior or commands
  changed.
- Hand the complete feature to the owner for the approved iPhone/Mac checks and
  record their result before starting `income-expense`.

## Checkpoint C: cash-balance complete

- Every success criterion in `SPEC-cash-balance.md` is satisfied within the
  owner-managed runtime-test boundary.
- No third-party package, CloudKit entitlement, network access, market data, AI,
  or MCP behavior has been added.
- The branch contains small, verified commits corresponding to the slices.
- The owner has enough instructions to run and judge the feature independently.

## Verification Commands

Use the exact commands from `SPEC-cash-balance.md`. Focused tests may use
`-only-testing:MonMonTests/<suite-or-test>` during a slice; every checkpoint runs
the complete macOS test target. iOS runtime automation is not required because
the owner has taken responsibility for hands-on device testing.

## Expected Change Map

```text
SPEC-cash-balance.md              approved source of truth
tasks/plan.md                     implementation order and checkpoints
tasks/todo.md                     detailed execution checklist after plan approval
MonMon.xcodeproj/project.pbxproj  explicit source/test file references
MonMon/App/                       model-container installation and feature root
MonMon/Accounts/                  model, validation, formatting, summary, and views
MonMonTests/Accounts/             validation, total, and persistence tests
README.md                         only if run or usage instructions change
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| SwiftData macro rejects or transforms `Decimal` or the enum unexpectedly | High | Make an exact in-memory save/fetch test the first implementation slice |
| Vietnamese separators parse differently under another system locale | High | Use an explicit locale and cover grouped/ungrouped values in unit tests |
| A failed save leaves an unsaved row visible through `@Query` | Medium | Roll back the failed insert and retain only the form draft/error state |
| Shared form layout behaves differently on iPhone and Mac | Medium | Keep controls adaptive and give the owner a focused cross-platform checklist |
| No local iOS Simulator runtime is installed | Low | Compile against the Simulator SDK automatically; owner runs the chosen device |
| The first persisted schema complicates later CloudKit work | Medium | Keep fields nonoptional with stable defaults and defer CloudKit configuration to its approved module |

## Scope Guard

This plan ends after adding and listing local VND cash/bank opening balances. It
does not add account maintenance, transactions, multiple currencies, iCloud,
financial APIs, market prices, AI analysis, or MCP tools.

## Open Questions

None. Detailed task execution begins only after the owner approves this plan and
then approves its checklist.
