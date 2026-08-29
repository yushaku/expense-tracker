# Implementation Plan: Goal Envelopes

## Overview

Build the second module in `BUDGET-CAPABILITIES.md`: goals that earmark money
inside one jar, reserve a monthly contribution without duplicating the jar's
plan, and forecast progress toward a target.

## Dependency Graph

```text
Goal model + pure forecast contract
    |
    v
Draft validation + per-jar commitment capacity
    |
    v
SwiftData persistence + jar deletion integrity
    |
    v
Goal list/cards/editor inside Budget
    |
    v
Complete backup/restore integration
    |
    v
Review + full non-Simulator gates
```

## Architecture Decisions

- A goal is a planning overlay, not a financial account. Its earmarked amount is
  never included in Wealth and does not create transactions.
- One goal has one funding jar in this slice. Several goals may share a jar.
- The shared scarce resource is the jar's planned monthly income allocation.
  Aggregate goal contributions may not exceed it at save time.
- Existing goals are not mutated if later income or percentage edits cause an
  overcommitment; the list reports the deficit for owner correction.
- Goal calculations remain pure and calendar-parameterised. Views render
  prepared snapshots and forms own their save/dismiss behaviour.
- Goal backup fields are optional at the payload boundary so existing snapshots
  remain restorable.

## Task List

### Phase 1: Contract and foundation

- [ ] Task 1: Add RED tests for forecast, required monthly contribution, and validation.
- [ ] Task 2: Add the CloudKit-compatible goal model, pure engine, and draft.

### Checkpoint: Foundation

- [ ] Focused Goal tests pass.
- [ ] Goal model persists in an in-memory `MonMonSchema` container.

### Phase 2: Integrity and user flow

- [ ] Task 3: Aggregate jar commitments and block deletion of referenced jars.
- [ ] Task 4: Add accessible Goal list, cards, add/edit/delete form, and Budget entry point.
- [ ] Task 5: Add localized English and Vietnamese Goal copy.

### Checkpoint: Core flow

- [ ] Goal CRUD works end to end in code and compile checks.
- [ ] Shared-jar capacity and overcommitment states are visible and tested.

### Phase 3: Portability and completion

- [ ] Task 6: Extend complete backup validation, export, and authoritative restore.
- [ ] Task 7: Run SwiftUI correctness, quality, simplification, and security review.
- [ ] Task 8: Run focused/full tests, strict format lint, and compile-only iPhoneOS build.
- [ ] Task 9: Commit reviewable increments and hand back the clean feature branch.

### Checkpoint: Complete

- [ ] All `SPEC-goal-envelopes.md` success criteria are met.
- [ ] No Simulator, merge, push, or phone installation was performed.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Goal money accidentally inflates net worth | High | Keep Goal out of asset summaries and document it as an overlay |
| One jar promises the same monthly money twice | High | Validate aggregate contribution against its current planned allocation |
| Income changes make valid commitments stale | Medium | Preserve data and show an explicit overcommitted state |
| Jar deletion leaves dangling Goal references | High | Block deletion while goals reference the jar |
| New model is omitted from backup | High | Add document/service/validator tests in the same branch |
| Date math shifts at month boundaries | Medium | Parameterise Calendar and test beginning/end-of-month cases |

## Open Questions

None. Automatic transfers and Trip spending are explicitly deferred.
