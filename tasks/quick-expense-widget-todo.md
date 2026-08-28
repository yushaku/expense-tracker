# Tasks: Quick Expense Widget

## Task 1: Persist the three shared presets

- [x] Define stable Coffee, Lunch, and Fuel slots with the requested defaults.
- [x] Validate one visible emoji and a positive whole-VND amount.
- [x] Round-trip the ordered preset set through injected `UserDefaults`.
- [x] Recover to defaults when stored data is missing or malformed.
- [x] Verify focused preset tests.

Files: shared preset/store source, preset tests, project file.

## Task 2: Record only complete preset expenses

- [ ] Add a capture dependency method that commits only ready transactions.
- [ ] Prove a valid preset creates one transaction and no pending item.
- [ ] Prove missing defaults create neither a transaction nor pending item.
- [ ] Add the quick-expense App Intent dependency and app registration.
- [ ] Verify focused capture tests and compile the app target.

Files: capture service/intent, quick-expense intent, app registration, tests.

## Task 3: Add configuration UI and widget

- [ ] Add three accessible emoji/amount rows to transaction Defaults.
- [ ] Persist valid edits and reload the widget timeline.
- [ ] Add small and medium widgets with three native intent buttons.
- [ ] Add the widget target, embedding, Info.plist, and app-group entitlement.
- [ ] Verify the iOS SDK build.

Files: defaults view/editor, widget extension, project file.

## Task 4: Review and verification

- [ ] Run the full macOS unit suite.
- [ ] Run recursive Swift format lint.
- [ ] Run the non-Simulator iOS SDK build.
- [ ] Review correctness, readability, architecture, security, and performance.
- [ ] Commit on `feat/quick-expense-widget`; do not merge, push, or install.
