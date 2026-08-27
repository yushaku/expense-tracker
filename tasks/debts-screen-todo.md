# Tasks: Dedicated Debts Screen

## Task 1: Make Debts a pushed screen with a ratio chart

- [x] Remove modal-only navigation and dismissal UI from `DebtListView`.
- [x] Show an accessible borrowed-versus-lent doughnut from outstanding totals.
- [x] Show a textual zero state when both outstanding totals are zero.
- [x] Preserve add-debt, direction-filtered debt rows, detail navigation, and empty states.
- [x] Add Borrowed/Lent tabs that filter records without changing the global ratio chart.
- [x] Verify the focused debt tests and compile the screen.

Files: `MonMon/Debts/DebtListView.swift`

## Task 2: Reduce Wealth to two debt totals

- [x] Replace debt count, add action, and individual cards with two navigation cards.
- [x] Show exactly outstanding borrowed and outstanding lent values, including zero.
- [x] Open the matching Borrowed/Lent tab from each Wealth card.
- [x] Remove Wealth-owned debt editor and detail-route state made obsolete by the move.
- [x] Verify the focused debt tests and compile the integrated flow.

Files: `MonMon/Accounts/WealthView.swift`

## Task 3: Make Wealth Accounts summary-only

- [x] Replace inline account cards with one total-balance navigation card.
- [x] Remove Wealth-owned account Add/Edit state and the floating add button.
- [x] Keep Add/Edit available in `AccountsScreen`, including its empty state.
- [x] Reuse one card shell for Accounts, Investments, and Debts.

Files: `MonMon/Accounts/WealthView.swift`

## Task 4: Review and verification

- [x] Run the full macOS unit suite.
- [x] Run recursive Swift format lint.
- [x] Run the non-Simulator Debug build.
- [x] Review correctness, readability, architecture, security, and performance.
- [x] Commit on `feat/debts-screen`; do not merge, push, or install on iPhone.
