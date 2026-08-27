# Tasks: Dedicated Debts Screen

## Task 1: Make Debts a pushed screen with a ratio chart

- [ ] Remove modal-only navigation and dismissal UI from `DebtListView`.
- [ ] Show an accessible borrowed-versus-lent doughnut from outstanding totals.
- [ ] Show a textual zero state when both outstanding totals are zero.
- [ ] Preserve add-debt, grouped debt rows, detail navigation, and empty states.
- [ ] Verify the focused debt tests and compile the screen.

Files: `MonMon/Debts/DebtListView.swift`

## Task 2: Reduce Wealth to two debt totals

- [ ] Replace debt count, add action, and individual cards with one navigation card.
- [ ] Show exactly outstanding borrowed and outstanding lent values, including zero.
- [ ] Remove Wealth-owned debt editor and detail-route state made obsolete by the move.
- [ ] Verify the focused debt tests and compile the integrated flow.

Files: `MonMon/Accounts/WealthView.swift`

## Task 3: Review and verification

- [ ] Run the full macOS unit suite.
- [ ] Run recursive Swift format lint.
- [ ] Run the non-Simulator Debug build.
- [ ] Review correctness, readability, architecture, security, and performance.
- [ ] Commit on `feat/debts-screen`; do not merge, push, or install on iPhone.
