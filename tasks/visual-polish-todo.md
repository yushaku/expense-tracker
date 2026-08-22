# Checklist: cash-balance-visual-polish

## Documentation

- [x] Objective and visual direction are explicit.
- [x] Data and behavior changes are excluded.
- [x] Owner requested immediate implementation.

## Slice 1: Dashboard

- [ ] Semantic Light/Dark colors are shared across iPhone and Mac.
- [ ] Total is the primary visual element and handles large values.
- [ ] Empty state has one clear primary Add action.
- [ ] Account cards show icon, name, kind, and exact formatted balance.
- [ ] Existing tests, macOS Debug build, formatter, and project validation pass.

## Slice 2: Add form

- [ ] Name, kind, and opening balance have clear grouped hierarchy.
- [ ] Existing identifiers, validation, Cancel, Save, and rollback remain intact.
- [ ] Errors use icon and text rather than color alone.
- [ ] Full tests/builds, iOS type-check, formatter, and review pass.

## Owner runtime gate

- [ ] Empty and populated states feel polished on a chosen device.
- [ ] Light and Dark Mode both look coherent.
- [ ] Dynamic Type, large balances, iPhone keyboard, and Mac resizing are usable.
- [ ] Owner accepts the visual direction or supplies focused feedback.
