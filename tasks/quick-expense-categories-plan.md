# Implementation Plan: Quick Expense Categories

## Architecture Decisions

- Extend the shared preset with an optional category UUID so the widget passes
  only a slot while the app-owned intent resolves the full typed preset.
- Preserve `nil` as an explicit Transaction-default compatibility mode.
- Add a typed quick-expense preparation path to the existing capture service;
  do not encode category selection into natural-language text.
- Query categories once in the parent editor and pass expense-only options to
  each row.

## Slices

1. Extend persistence and drafts with backward-compatible category IDs; prove
   round-trip and old-payload behavior.
2. Record a typed preset with explicit-category validation; prove override,
   default, and stale-category behavior.
3. Add accessible per-row category pickers and localized validation.
4. Run all quality gates, review, and commit the feature branch.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Old payload fails to decode | High | `decodeIfPresent` plus legacy JSON test |
| Deleted category records as Food | High | Distinguish explicit stale ID from nil default |
| Income category used for expense | High | Validate `kind == .expense` before commit |
| Nine rows become dense | Medium | Put category picker on its own responsive row |
