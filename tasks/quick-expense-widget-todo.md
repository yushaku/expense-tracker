# Tasks: Quick Expense Widget

## Task 1: Persist the three shared presets

- [x] Define stable Coffee, Lunch, and Fuel slots with the requested defaults.
- [x] Validate one visible emoji and a positive whole-VND amount.
- [x] Round-trip the ordered preset set through injected `UserDefaults`.
- [x] Recover to defaults when stored data is missing or malformed.
- [x] Verify focused preset tests.

Files: shared preset/store source, preset tests, project file.

## Task 2: Record only complete preset expenses

- [x] Add a capture dependency method that commits only ready transactions.
- [x] Prove a valid preset creates one transaction and no pending item.
- [x] Prove missing defaults create neither a transaction nor pending item.
- [x] Add the quick-expense App Intent dependency and app registration.
- [x] Verify focused capture tests and compile the app target.

Files: capture service/intent, quick-expense intent, app registration, tests.

## Task 3: Add configuration UI and widget

- [x] Add three accessible emoji/amount rows to transaction Defaults.
- [x] Persist valid edits and reload the widget timeline.
- [x] Add small and medium widgets with three native intent buttons.
- [x] Add the widget target, embedding, Info.plist, and app-group entitlement.
- [x] Verify the iOS SDK build.

Files: defaults view/editor, widget extension, project file.

## Task 4: Review and verification

- [ ] Run the full macOS unit suite.
- [ ] Run recursive Swift format lint.
- [ ] Run the non-Simulator iOS SDK build.
- [ ] Review correctness, readability, architecture, security, and performance.
- [ ] Commit on `feat/quick-expense-widget`; do not merge, push, or install.
