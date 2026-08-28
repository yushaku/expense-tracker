# Spec: Configurable Quick Expense Count

## Objective

Let the owner choose whether the Quick Expense widget uses 3, 6, or 9
editable presets. Preserve all nine configured values when the visible count is
reduced. Show at most 3 presets in a small widget, 6 in a medium widget, and 9
in a large widget so every action remains comfortably tappable. Each preset can
also use its own expense category; see `SPEC-quick-expense-categories.md`.

## Defaults and Migration

- Preserve the existing Coffee (`☕`, 35,000 VND), Lunch (`🍜`, 50,000 VND),
  and Fuel (`⛽`, 100,000 VND) presets.
- Add editable defaults for Groceries (`🛒`, 200,000 VND), Parking (`🅿️`,
  20,000 VND), Transit (`🚌`, 15,000 VND), Medicine (`💊`, 100,000 VND),
  Entertainment (`🎬`, 150,000 VND), and Bills (`🧾`, 500,000 VND).
- Migrate the existing three-preset JSON payload without changing the owner's
  custom emoji or amount. Migrated configurations start with a visible count
  of three and receive defaults for the six new slots.
- Missing or malformed storage recovers to the nine defaults with a visible
  count of three.

## App Experience

- Add a 3/6/9 segmented selector to Spending → Defaults → Quick expenses.
- Display and validate only the selected number of editor rows, while keeping
  all nine drafts in memory and persistence.
- Save the visible count and all nine presets atomically, then reload the
  WidgetKit timeline.
- Continue using the shared transaction-default account. Each preset uses its
  configured expense category, or the transaction-default category when left
  on “Transaction default.”

## Widget Experience

- Small family: first 3 active presets in one column.
- Medium family: first 6 active presets in a three-column grid.
- Large family: first 9 active presets in a three-column grid.
- If the configured count exceeds a family's capacity, that family displays
  only its prefix. The configuration itself is not changed.
- Every button remains a native `Button(intent:)`. A successful action returns
  the localized “Saved in MonMon.” dialog and reloads the timeline.

## Quality Gates

- Focused unit tests for defaults, 3/6/9 round trips, legacy migration,
  malformed recovery, hidden-value retention, and complete-set validation.
- Full macOS unit suite.
- Recursive Swift format lint.
- Generic iOS SDK build with code signing disabled.
- Physical-iPhone validation only after an approved merge into `dev`.

## Success Criteria

- The app can save any supported visible count: 3, 6, or 9.
- Existing owners keep their first three customized presets after migration.
- Reducing and later increasing the count restores the hidden configured
  values.
- Small, medium, and large widgets show no more than 3, 6, and 9 actions,
  respectively.
- The widget refreshes after in-app changes and after a successful expense.
- Each preset records against its configured expense category.

## Open Questions

None. The six new defaults are starting values only; every emoji and amount is
editable in the app.
