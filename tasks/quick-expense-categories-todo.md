# Tasks: Quick Expense Categories

## 1. Persist category identity

- [x] Add optional category IDs to preset and draft contracts.
- [x] Preserve category IDs during normalization and hidden-preset saves.
- [x] Prove round-trip and legacy decoding with focused tests.

## 2. Record the configured category

- [x] Add typed quick-expense preparation using the default account.
- [x] Override the global category only for a valid explicit expense category.
- [x] Reject stale/income categories without writing or staging review.
- [x] Prove the behavior with capture-service tests.

## 3. Configure categories in-app

- [x] Query and display current expense categories in every visible row.
- [x] Support Transaction default and stale-selection states.
- [x] Add localized labels, validation, and accessibility identifiers.

## 4. Verify and commit

- [x] Run focused and full macOS tests.
- [x] Run recursive Swift format lint.
- [x] Run the generic iOS SDK build.
- [x] Review and commit on `feat/quick-expense-categories`.
