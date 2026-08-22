# Plan: cash-balance-visual-polish

**Status:** Approved through owner direction (2026-08-23)

## Slice 1: Dashboard hierarchy

1. Add small shared semantic design tokens for both platforms.
2. Replace the default List presentation with a responsive scrolling dashboard.
3. Add total, empty, and account-card presentations without changing `@Query`.
4. Build and run the existing tests before committing.

## Slice 2: Form hierarchy

1. Replace default Form chrome with focused native input cards.
2. Preserve bindings, validation messages, Save/Cancel, explicit save, and rollback.
3. Run macOS tests/build, direct iOS type-check, formatter, and project validation.
4. Review only visual files and hand runtime evaluation back to the owner.

## Risks

- Large currency values may truncate: use one line, monospaced digits, and a
  minimum scale factor.
- Platform surfaces differ: resolve them in semantic theme tokens.
- Styling can weaken accessibility: retain native controls, labels, identifiers,
  and error icons with text.
