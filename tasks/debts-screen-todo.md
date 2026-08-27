# Tasks: Dedicated Debts Screen

## Task 1: Make Debts a pushed screen with a ratio chart

- [x] Remove modal-only navigation and dismissal UI from `DebtListView`.
- [x] Show an accessible borrowed-versus-lent doughnut from outstanding totals.
- [x] Show a textual zero state when both outstanding totals are zero.
- [x] Preserve add-debt, grouped debt rows, detail navigation, and empty states.
- [x] Verify the focused debt tests and compile the screen.

Files: `MonMon/Debts/DebtListView.swift`

## Task 2: Reduce Wealth to two debt totals

- [x] Replace debt count, add action, and individual cards with one navigation card.
- [x] Show exactly outstanding borrowed and outstanding lent values, including zero.
- [x] Remove Wealth-owned debt editor and detail-route state made obsolete by the move.
- [x] Verify the focused debt tests and compile the integrated flow.

Files: `MonMon/Accounts/WealthView.swift`

## Task 3: Review and verification

- [x] Run the full macOS unit suite.
- [x] Run recursive Swift format lint.
- [x] Run the non-Simulator Debug build.
- [x] Review correctness, readability, architecture, security, and performance.
- [x] Commit on `feat/debts-screen`; do not merge, push, or install on iPhone.
