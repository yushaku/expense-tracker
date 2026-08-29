# Implementation Plan: Trip Workspace

## Overview

Extend fully funded Trip goals into real-expense workspaces. A workspace is an
overlay for explaining a trip; ordinary transactions remain the only source of
truth for accounts, categories, and spending.

## Dependency Graph

```text
TripWorkspace model + lifecycle
    |
    v
Transaction trip link + jar override
    |
    v
Override-first Budget routing
    |
    v
Derived Trip summary + integrity rules
    |
    v
Goal entry + Trip list/detail/editor UI
    |
    v
Backup/restore + reconciliation
    |
    v
Review + non-Simulator gates
```

## Architecture Decisions

- Store one workspace plus UUID references; do not add a parallel ledger or a
  synthetic transfer.
- Freeze the funded budget and presentation at start, then derive every
  spending value from linked expense transactions.
- Keep transaction category and Budget routing separate: an explicit jar
  override wins, otherwise the category mapping and existing fallback apply.
- Completed trips remain editable for corrections; completion changes only
  workspace state.
- Decode new backup arrays and fields as optional so legacy backup documents
  remain valid.

## Task List

### Phase 1: Workspace foundation

- [x] Task 1: Add RED tests for persistence, start eligibility, duplicate
  prevention, completion, and reopening.
- [x] Task 2: Implement the model, status, schema registration, and lifecycle.

### Checkpoint: Lifecycle integrity

- [x] A fully funded Trip goal starts exactly one active workspace.
- [x] Completing and reopening mutate no ledger or goal amounts.

### Phase 2: Financial integration

- [ ] Task 3: Preserve trip and jar-override metadata through transaction
  create/edit/delete/undo paths.
- [ ] Task 4: Route Budget expenses by valid override before category mapping
  and protect referenced jars.
- [ ] Task 5: Derive exact budget, spent, remaining, over-budget, and category
  breakdowns from linked expenses only.

### Checkpoint: Financial integrity

- [ ] Trip totals reconcile exactly to ordinary expense transactions.
- [ ] Trip metadata does not change account totals or create money movement.

### Phase 3: Owner experience

- [ ] Task 6: Add ready, active, and completed Trip sections with lifecycle
  actions inside Goals.
- [ ] Task 7: Add Trip detail, category breakdown, linked transactions, and an
  Add expense entry point.
- [ ] Task 8: Add Trip and jar-routing controls to the transaction editor.
- [ ] Task 9: Add English/Vietnamese copy and complete the SwiftUI correctness
  and accessibility checklist.

### Phase 4: Portability and completion

- [ ] Task 10: Extend complete backup/restore, validation, recovery, and store
  reconciliation with legacy compatibility.
- [ ] Task 11: Run code-quality, simplification, and security reviews.
- [ ] Task 12: Run focused/full tests, strict format lint, and compile-only
  iPhoneOS build.
- [ ] Task 13: Commit reviewable increments and hand back a clean feature
  branch.

### Checkpoint: Complete

- [ ] All `SPEC-trip-workspace.md` success criteria are met.
- [ ] No Simulator, merge, push, or phone installation was performed.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Trip becomes a second balance | High | Persist no spent/remaining balance; derive from linked expenses |
| Spending is counted twice | High | Keep existing account totals unchanged and add neutrality tests |
| Category detail is lost | High | Store trip and jar override beside, never instead of, category |
| Jar deletion rewrites history | High | Block deletion while any workspace references the jar |
| Workspace deletion orphans metadata | High | Cancel only empty active workspaces; retain completed history |
| Legacy backup stops importing | High | Optional decode defaults plus legacy validation/restore tests |

## Open Questions

None. Fund liquidation, shared trips, itinerary planning, and receipt/media
storage remain explicitly deferred.
