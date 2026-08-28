# Implementation Plan: Quick Expense Widget

## Overview

Build the shared preset contract first, add a ready-only app-owned transaction
intent second, then add the in-app editor and WidgetKit extension around those
tested boundaries.

## Architecture Decisions

- Store only three small preset values in app-group `UserDefaults`; the widget
  never opens or duplicates the SwiftData stack.
- Execute the action in the main app process. Use iOS 26 background intent
  modes and Apple's compatibility conformance on iOS 18-25.
- Reuse `TransactionCaptureService` and the current transaction defaults. Add a
  ready-only entry point so invalid defaults cannot create pending captures.
- Use a static widget configuration because presets are edited in MonMon, not
  in the system widget configuration sheet.
- Rely on WidgetKit's guaranteed timeline reload after `perform()` returns; ask
  WidgetCenter for a reload when presets are edited in-app.

## Task List

1. Add the shared preset/store contract and unit tests.
2. Add ready-only capture and the app-process quick-expense intent with tests.
3. Add the accessible in-app preset editor and WidgetKit extension target.
4. Run full tests, lint, iOS SDK build, and a final code review.

Tasks are tracked in `tasks/quick-expense-widget-todo.md` so existing feature
plans remain intact.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Widget extension writes a different store | High | Restrict intent execution to the main app process |
| Missing defaults stage an uncertain item | High | Require `ParsedTransactionCapture.isReady` before commit |
| Older iOS lacks intent modes | Medium | Use Apple's compatibility conformance for iOS 18-25 |
| Invalid edits replace working presets | Medium | Validate the complete three-slot set before saving |
| Widget shows stale values after edits | Medium | Reload its timeline after each valid persisted edit |

## Open Questions

None; the user-provided examples and existing transaction-default behavior
fully determine this slice.
