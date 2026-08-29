# Implementation Plan: Income Allocation Timeline

## Overview

Capture a frozen explanation beside each received income transaction and expose
it as a month-selectable timeline inside Budget. Existing income is backfilled
once as estimated; snapshot metadata never enters financial totals.

## Dependency Graph

```text
Pure snapshot + versioned codec
    |
    v
MoneyTransaction optional storage + edit/delete lifecycle
    |
    v
Manual, recurring, import, and capture creation boundaries
    |
    v
Legacy backfill + timeline preparation
    |
    v
Accessible Budget timeline UI
    |
    v
Complete backup/restore integration
    |
    v
Review + non-Simulator gates
```

## Architecture Decisions

- Embed one optional snapshot string in `MoneyTransaction`; avoid a second
  persistent event graph whose lifecycle could drift from the ledger row.
- Freeze jar UUID, presentation, percentage, and exact allocated amount. Jar
  configuration remains editable without rewriting history.
- Keep the feature explanatory only. Budget's live current-plan math and all
  financial balances remain unchanged.
- Capture new income at every production creation boundary. Backfill only
  snapshot-less legacy income and label it estimated.
- Use one canonical codec/validator for local reads and untrusted backup import.

## Task List

### Phase 1: Snapshot contract

- [ ] Task 1: Add RED tests for exact distribution, rounding, freezing, and amount refresh.
- [ ] Task 2: Implement the versioned snapshot, codec, and optional transaction storage.

### Checkpoint: Snapshot foundation

- [ ] Focused pure tests pass.
- [ ] Snapshot round-trips without changing any ledger calculation.

### Phase 2: Transaction lifecycle

- [ ] Task 3: Capture and refresh snapshots in manual transaction edit/create and undo.
- [ ] Task 4: Capture snapshots in recurring generation.
- [ ] Task 5: Capture snapshots in statement import and pending-capture commit.
- [ ] Task 6: Backfill missing legacy income idempotently as estimated.

### Checkpoint: Lifecycle integrity

- [ ] Every production income creation path is covered by an integration test.
- [ ] Edit, delete/undo, malformed data, and legacy backfill tests pass.

### Phase 3: Owner experience and portability

- [ ] Task 7: Add timeline preparation and accessible month-selectable SwiftUI inside Budget.
- [ ] Task 8: Add English/Vietnamese copy and explicit historical-vs-current explanation.
- [ ] Task 9: Extend complete backup validation, export, and authoritative restore.

### Phase 4: Completion

- [ ] Task 10: Run SwiftUI, quality, simplification, and security review.
- [ ] Task 11: Run focused/full tests, strict format lint, and compile-only iPhoneOS build.
- [ ] Task 12: Commit reviewable increments and hand back a clean feature branch.

### Checkpoint: Complete

- [ ] All `SPEC-income-allocation-timeline.md` success criteria are met.
- [ ] No Simulator, merge, push, or phone installation was performed.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Snapshot money does not reconcile to income | High | Deterministic rounding plus explicit unallocated remainder and equality tests |
| One creation path omits capture | High | Enumerate and integration-test manual, recurring, import, and capture boundaries |
| Jar edits rewrite history | High | Store frozen presentation and percentage inside the snapshot |
| Embedded JSON becomes malformed | High | Versioned codec, strict validator, no silent overwrite, backup rejection |
| Snapshot starts affecting balances | High | Keep all existing summary inputs unchanged and add neutrality tests |
| Legacy backup checksum changes | High | Encode the optional transaction field only when present and keep legacy tests |

## Open Questions

None. Projected future events and historical monthly Budget snapshots are
explicitly deferred.
