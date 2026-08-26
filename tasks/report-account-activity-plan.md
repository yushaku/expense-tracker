# Implementation plan: Report monthly overview and account activity

## Overview

Separate the monthly summary month from the existing report query, add tested
account-expense aggregation, then expose a read-only all-time account activity
timeline containing transactions and transfers.

## Dependency graph

```text
monthly transaction selection
    -> account expense aggregation
        -> Report account section

account activity ordering
    -> account activity detail view
        -> Report account navigation
```

## Architecture decisions

- `summaryMonth` is independent of `TransactionQuery.range`; the month rail owns
  the former and the calendar toolbar owns the latter.
- Accounting aggregation stays pure and expense-only. SwiftUI receives rows and
  resolves them to the existing accounts for display.
- Account detail is read-only and all-time. It combines existing transaction and
  transfer cards in a single newest-first timeline without adding persistence or
  editing behavior.
- Existing `tasks/plan.md` and `tasks/todo.md` remain untouched because they
  track the active Import Reconciliation initiative.

## Task list

1. Add and test monthly account-spending aggregation.
2. Add and test unified account activity selection and ordering.
3. Separate Report summary month and add account rows/detail navigation.
4. Run focused/full available unit tests, format lint, review, and commit.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Monthly overview accidentally follows search filters | Medium | Compute it from `summaryRange` and the unfiltered transaction query result. |
| Transfers are counted as spending | High | Aggregation accepts only `MoneyTransaction` expenses; regression tests cover neutrality. |
| Account activity misses incoming transfers | High | Filter both source and destination ids in pure tested logic. |
| Equal timestamps reorder unpredictably | Low | Add an explicit stable id tie-break. |
| ReportView grows further | Medium | Put aggregation and new UI in focused files. |

## Verification checkpoints

- Foundation: new aggregation/activity tests pass with existing summary suites.
- UI integration: focused Report/search logic tests and recursive format lint pass.
- Complete: staged diff has no unrelated edits; no iPhone build/install/launch is
  performed on this feature branch.

## Open questions

None.
