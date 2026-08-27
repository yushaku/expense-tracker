# Implementation Plan: Normal and Credit Accounts

## Overview

Introduce one canonical Normal account kind with backward-compatible decoding for
stored Cash/Bank values, add a persisted Credit limit, expose it through the
editor and account card, and keep backup restore compatible with old snapshots.

## Dependency Graph

```text
Normal/Credit kind compatibility + credit-limit model
    |
    +--> draft validation + persistence tests
    |
    +--> available-credit calculation + account UI
    |
    +--> backup export/validation/restore compatibility
    |
    +--> remove legacy source references and migration adapters
            |
            v
        full quality gates and review
```

## Architecture Decisions

- Canonical encoded kinds are `normal` and `credit`; legacy `cash` and `bank`
  decode to `normal` so stored and backed-up data remains readable.
- Keep temporary source aliases while converting consumers incrementally, then
  remove them after repository-wide search proves no production/test references
  remain.
- Add `creditLimit` additively with a zero default so existing SwiftData rows and
  CloudKit records remain valid.
- Store a card's limit, not its changing available amount. Derive available credit
  as `max(0, creditLimit + currentBalance)` from the existing ledger balance.
- Add an optional credit-limit field to backup records without bumping format v1;
  omission means zero, preserving restore compatibility with existing backups.
- Do not use available credit as spendable owner cash and do not enforce it in
  transaction source-balance guards in this feature.
- Existing `tasks/plan.md` and `tasks/todo.md` remain untouched because they record
  the completed Full Backup and Restore initiative; this feature uses scoped task
  files.

## Increment Strategy

1. Add the compatible kind/model/draft contract with RED/GREEN tests and temporary
   aliases so every intermediate commit compiles.
2. Add pure available-credit behavior and the Credit editor/card presentation.
3. Extend backup export, validation, and restore with old/new snapshot tests.
4. Convert production and preview consumers from Cash/Bank to Normal in small
   groups.
5. Convert test fixtures by domain, remove the temporary aliases, and prove no
   legacy source references remain.
6. Update localization, perform review/simplification, and run all non-Simulator
   gates.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Existing SwiftData enum payloads stop decoding | High | Decode `cash`/`bank` explicitly and cover legacy serialized values before removing aliases |
| New non-optional field breaks existing rows/CloudKit | High | Add with a zero default; persistence-test a legacy-shaped account path |
| Old backups fail validation or restore | High | Make backup field optional, default it to zero, and test old plus new records |
| Borrowing capacity is counted as wealth | High | Keep current balance as the only ledger input; test allocation/net-worth neutrality |
| UI implies the limit is enforced | Medium | Present “available credit” as information and keep enforcement outside the spec |
| Mechanical kind replacement changes another `.cash` enum | Medium | Replace only typed `CashAccountKind` sites and use compiler plus focused tests |

## Verification Checkpoints

- Contract checkpoint: focused account draft, persistence, and balance tests pass;
  legacy raw values decode as Normal.
- UI/backup checkpoint: focused account and backup suites pass; source compiles with
  temporary aliases.
- Migration checkpoint: `rg` finds no CashAccountKind Cash/Bank consumers or stale
  user-facing choices; aliases are removed.
- Complete: full macOS tests, format lint, macOS build, generic iOS device build,
  staged-diff review, and five-axis code review pass.

## Open Questions

None.
