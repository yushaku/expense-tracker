# Implementation Plan: Dedicated Debts Screen

## Overview

Turn the existing unused `DebtListView` into a pushed management screen with a
borrowed-versus-lent doughnut and direction tabs, then replace the individual
debt cards on Wealth with separate Borrowed and Lent summary cards.

## Architecture Decisions

- Reuse `DebtSummary.totalOutstanding` for every displayed amount; no new
  financial calculation or model type.
- Reuse `AllocationDoughnut` with positive borrowed/lent slices. When both are
  zero, show a textual zero-balance summary rather than an empty chart.
- Let Wealth's existing `NavigationStack` own the Debts screen. Remove the
  nested stack and modal-only Done action from `DebtListView`.
- Use destination-based `NavigationLink` values for both screen transitions,
  matching the repository's reliable push-navigation pattern.
- Keep the doughnut global while the tabs filter only the records underneath;
  otherwise each tab would render a meaningless single-slice ratio.
- Use localized strings and existing theme tokens; add no dependency.

## Task List

1. Convert `DebtListView` into a pushed screen and add the accessible doughnut.
2. Replace Wealth's inline debt management with two direction-specific cards.
3. Reduce Wealth Accounts to one total-balance card and keep Add/Edit inside
   `AccountsScreen`.
4. Run full tests, format lint, non-Simulator build, and five-axis review.

Tasks are tracked in `tasks/debts-screen-todo.md` so the completed backup plan
in the default task files remains intact.

## Risks and Mitigations

| Risk                                            | Impact | Mitigation                                                                   |
| ----------------------------------------------- | ------ | ---------------------------------------------------------------------------- |
| Nested navigation blocks back/detail pushes     | High   | Remove the inner stack and use direct destinations                           |
| Settled debts yield a zero-total chart          | Medium | Render an explicit zero state when both totals are zero                      |
| Colour alone conveys direction                  | Medium | Keep symbols, labels, amounts, percentages, and VoiceOver legend text        |
| Wealth accidentally retains management controls | Medium | Remove editor state, add button, debt cards, and route registration together |

## Open Questions

None; the owner approved implementation from `SPEC-debts-screen.md`.
