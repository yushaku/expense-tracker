# Implementation Plan: Import Reconciliation and Commit

## Overview

Implement the approved `import-reconciliation` module behind the existing Import
Inbox. A complete parsed statement gains account assignment, conservative
duplicate and transfer matching, per-row resolution, and one failure-safe commit
that writes SwiftData provenance before removing the staged PDF.

The work remains sequential because the schema, pure contracts, persistence
service, observable state, and UI depend on one another. Every increment uses
synthetic candidates and in-memory stores; no owner statement enters Git or test
output.

## Dependency Graph

```text
Validated import id + optional model provenance
    |
    v
CloudKit duplicate folding in StoreReconciler
    |
    v
Pure candidate matching + row resolutions
    |                    |
    |                    +--> remembered statement-account mapping
    v
Dedicated-context transaction commit/linking
    |
    v
Transfer commit/linking + staged cleanup recovery
    |
    v
Main-actor reconciliation/commit state
    |
    v
Row editor UI --> commit summary/result UI
    |
    v
Full gates + physical acceptance on Yushaku
```

## Architecture Decisions

- Introduce one validated `ImportSourceID` value type for lowercase SHA-256
  fingerprints. Models persist its raw string only after validation.
- Add optional provenance fields to `MoneyTransaction` and `AccountTransfer`
  with default `nil`, preserving manual, recurring, and existing records while
  allowing lightweight private-CloudKit migration.
- Extend `StoreReconciler` separately from import commit. It is the eventual
  consistency guard for two devices that imported the same source while offline.
- Keep matching free of SwiftData and SwiftUI. Immutable snapshots of accounts,
  categories, transactions, and transfers cross into a pure reconciler.
- Keep exact matches read-only. A possible transaction or transfer begins
  unresolved and always needs an owner decision.
- Use the existing direction-specific category defaults, but no merchant rule
  or description-text inference.
- Store the bank/account-suffix mapping in UserDefaults only after a successful
  financial save. A stale mapping never selects an arbitrary account; import
  falls back only to the current valid transaction default.
- Give the commit service a dedicated `ModelContext`. It re-fetches and
  revalidates ids immediately before one save, so unrelated view edits cannot be
  rolled back and stale reconciliation cannot write.
- Financial save precedes staged cleanup. A cleanup failure leaves the PDF and
  exposes retry; exact provenance prevents a repeated financial write.
- Model row review as explicit status and resolution enums. The UI never infers
  commit readiness from counts or colors.
- Keep parsed amount, direction, timestamp, reference, and page immutable.
  Editable output is limited to category, resulting note, skip/link choice, and
  transfer account.

## Task List

### Phase 1: Provenance foundation

- [x] Task 1: Add validated import provenance to transaction and transfer models
- [x] Task 2: Fold duplicate imported records after CloudKit convergence

### Checkpoint: Provenance

- [x] Optional-field migration opens existing and in-memory stores.
- [x] Invalid hashes cannot enter an import write path.
- [x] Manual and recurring records are untouched by import reconciliation.
- [x] Same-side imported duplicates converge deterministically.

### Phase 2: Pure reconciliation

- [x] Task 3: Classify exact, possible, new, and unresolved candidates
- [x] Task 4: Resolve and remember the statement account safely

### Checkpoint: Reconciliation

- [x] Matching uses account, direction, exact Decimal amount, currency, and
      Vietnam local day only.
- [x] Notes never influence matching.
- [x] Possible and ambiguous matches remain explicit owner decisions.
- [x] Defaults never resolve to stale or wrong-direction records.

### Phase 3: Atomic financial commit

- [x] Task 5: Commit and link ordinary transactions idempotently
- [x] Task 6: Commit/link transfers and recover staged cleanup failures

### Checkpoint: Persistence

- [x] One invalid row prevents every financial/provenance write.
- [x] Repeating a request cannot create a second record for one fingerprint.
- [x] Historical transfers bypass today's balance restriction but retain all
      other `TransferDraft` validation.
- [x] PDF removal happens only after a successful save and is safely retryable.

### Phase 4: Owner-facing review and commit

- [x] Task 7: Add observable reconciliation and commit phases
- [x] Task 8: Add account selection and focused row-resolution editor
- [x] Task 9: Add commit confirmation, results, cleanup retry, and count refresh

### Checkpoint: UI

- [x] Incomplete statements never expose an enabled commit action.
- [x] Every row announces New, Possible duplicate, Already imported, Transfer,
      Skipped, or Needs attention without relying on color.
- [x] Commit readiness follows validated row state and current model snapshots.
- [x] Success and cleanup failure are visibly distinct and idempotent.
- [x] Accessibility identifiers contain no filename, suffix, reference, note,
      or import fingerprint.

### Phase 5: Completion gates

- [ ] Task 10: Review, verify, deploy to `Yushaku`, and hand off acceptance

### Checkpoint: Complete

- [ ] Approved spec and plan acceptance criteria are met.
- [ ] Full macOS tests and recursive Swift format lint pass.
- [ ] Compile-only iOS SDK build passes without running a Simulator.
- [ ] Physical build, install, and launch succeed on `Yushaku`.
- [ ] Owner imports the staged statement and verifies resulting records.
- [ ] No real statement, raw provenance, local path, generated output, or
      unrelated edit exists in the diff.

## Increment and Commit Strategy

Each task lands as one tested save-point commit. Tasks 5 and 6 may touch the same
service and test files but remain separate because transaction writes can ship
and be reviewed independently of transfer-side linking and filesystem cleanup.
UI tasks do not begin until the persistence checkpoint is green.

Expected commit sequence:

1. `feat: add bank import provenance`
2. `fix: reconcile duplicate bank imports`
3. `feat: classify statement import candidates`
4. `feat: remember statement account mapping`
5. `feat: commit reconciled bank transactions`
6. `feat: commit and link bank transfers`
7. `feat: model statement reconciliation state`
8. `feat: add statement row reconciliation editor`
9. `feat: commit reviewed bank statements`
10. Verification/docs commit only if the checklist changes after acceptance.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Optional provenance fields fail against an existing CloudKit store | High | Add defaults, avoid uniqueness annotations, run old-record and CloudSync schema tests before service work. |
| Two devices import the same candidate while offline | High | Revalidate before save and fold shared non-nil fingerprints deterministically on launch/foreground. |
| Same-day equal amounts create false duplicate suggestions | High | Suggestions never auto-link; require same account/direction/currency and explicit owner choice. |
| Linking mutates a record that changed after preview | High | Dedicated context re-fetches and repeats eligibility checks immediately before save. |
| Transfer is counted as income/expense | High | Create `AccountTransfer`, never paired `MoneyTransaction`; cover balance and Spending totals in persistence tests. |
| Save succeeds but staged deletion fails | High | Save provenance first, return cleanup-needed state, and make cleanup independently retryable. |
| Stale UserDefaults mapping selects the wrong account | High | Key by bank plus suffix, validate current account id/currency, and never use bank-only fallback. |
| Large statement makes row editing sluggish | Medium | Pure reconciliation is one pass over candidates with indexed fingerprints; keep row editors focused and lazy. |
| Source data leaks through errors or accessibility | High | Closed error mapping and static/index identifiers; inspect staged diff for references, hashes, paths, and fixtures. |

## Verification Strategy

- Follow failing-test-first TDD for every domain and persistence behavior.
- Use synthetic 64-character fingerprints, candidates, accounts, and categories.
- Use in-memory `ModelContainer` tests for migration defaults, atomic commit,
  idempotency, balance effects, and reconciliation after duplicate sync.
- Inject UserDefaults suite names and cleanup/save seams; never mutate owner
  defaults or App Group data in unit tests.
- Run focused suites at every task and the full test suite at each checkpoint.
- Run recursive format lint and compile-only iOS SDK build before physical work.
- After every relevant UI/app increment, run `rtk scripts/run-iphone.sh Yushaku`;
  report build/install/launch only. The owner owns hands-on acceptance.

## Review Checklist

- [x] Schema changes are optional, defaulted, private, and migration-safe.
- [ ] Matching behavior exactly follows the approved conservative fields.
- [ ] Possible matches never become automatic decisions.
- [ ] Dedicated-context save and cleanup ordering match the spec.
- [ ] Repeated and interrupted commits are idempotent.
- [ ] Existing manual, recurring, transaction, transfer, parser, and inbox flows
      retain their behavior.
- [ ] No dependency, background task, OCR, CSV, or other-bank scope is added.

## Open Questions

None. The owner approved this implementation plan before Task 1 began.
