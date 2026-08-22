# Checklist: cash-balance-visual-polish

**Status:** Automated implementation complete; awaiting owner visual review

## Documentation

- [x] Objective and visual direction are explicit.
- [x] Data and behavior changes are excluded.
- [x] Owner requested immediate implementation.

## Slice 1: Dashboard

- [x] Semantic Light/Dark colors are shared across iPhone and Mac.
- [x] Total is the primary visual element and handles large values.
- [x] Empty state has one clear primary Add action.
- [x] Account cards show icon, name, kind, and exact formatted balance.
- [x] Existing tests, macOS Debug build, formatter, and project validation pass.

**Evidence:** The dashboard uses platform-semantic canvas, surface, and field
colors plus shared navy/emerald tokens. The total scales on one line, account
cards use `ViewThatFits` to fall back to a vertical layout, and the Add action
retains its identifier. Full macOS tests, macOS Debug, strict formatting,
project validation, and direct iOS 18 type-check all exited 0 (2026-08-23).

## Slice 2: Add form

- [x] Name, kind, and opening balance have clear grouped hierarchy.
- [x] Existing identifiers, validation, Cancel, Save, and rollback remain intact.
- [x] Errors use icon and text rather than color alone.
- [x] Full tests/builds, iOS type-check, formatter, and review pass.

**Evidence:** Presentation moved into a focused `AddAccountForm` while
`AddAccountView` retains the original state and save orchestration. Name, type,
and amount use native fields inside semantic cards; every validation and save
error includes an SF Symbol and text. Existing accessibility identifiers are
unchanged. Full macOS tests, macOS Debug, direct iOS 18 type-check with warnings
as errors, strict formatting, and project validation all exited 0 (2026-08-23).
Final review also removed an accessibility-label override that could hide the
total amount from VoiceOver; tests, macOS Release, and iOS type-check passed
after that correction.

## Owner runtime gate

- [ ] Empty and populated states feel polished on a chosen device.
- [ ] Light and Dark Mode both look coherent.
- [ ] Dynamic Type, large balances, iPhone keyboard, and Mac resizing are usable.
- [ ] Owner accepts the visual direction or supplies focused feedback.
