# Implementation Plan: Configurable Quick Expenses

## Architecture Decisions

- Persist one version-tolerant configuration containing a typed 3/6/9 count
  and all nine ordered presets.
- Decode the current three-element array as a legacy format and merge it with
  the six new defaults.
- Keep count/prefix rules in the shared model so they can be unit-tested and
  reused by the app and widget.
- Use stable slot identity in the editor and native WidgetKit families/layouts.

## Slices

1. Specify and test the nine-slot configuration, persistence, and migration.
2. Add the 3/6/9 app selector and editable rows with localized accessibility.
3. Add family-aware small/medium/large widget layouts.
4. Run all quality gates, review the diff, and commit the feature branch.

## Risks

| Risk                                    | Mitigation                                       |
| --------------------------------------- | ------------------------------------------------ |
| Existing custom presets are overwritten | Legacy migration tests preserve all three values |
| Reducing count loses hidden presets     | Always persist all nine presets                  |
| Too many actions become hard to tap     | Family caps of 3/6/9 and three-column grids      |
| App and widget disagree on ordering     | Normalize by `QuickExpenseSlot.allCases`         |
