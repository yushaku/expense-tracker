# Tasks: Full Backup and Restore

## Task 0: Restore the baseline macOS quality gate

- [x] Guard the iOS-only `ShortcutsLink` on macOS.
- [x] Run focused/full macOS tests to prove the baseline compiles.
- [x] Commit the prerequisite independently.

Files: `MonMon/Settings/SettingsView.swift`

## Task 1: Define and encode the backup document

- [x] Start with failing round-trip and canonical-scalar tests.
- [x] Add format/version metadata, payload DTOs for all 14 models, preferences,
      deterministic sorting, JSON encoding/decoding, and payload SHA-256.
- [x] Prove deterministic bytes for logically identical snapshots.

Files: `MonMon/Backup/MonMonBackupDocument.swift`,
`MonMonTests/Backup/MonMonBackupDocumentTests.swift`, project file.

## Task 2: Validate imported snapshots before writes

- [x] Start with failing format, version, checksum, scalar, enum, duplicate-ID,
      provenance, and reference-integrity tests.
- [x] Return a content-safe restore preview containing record counts and export
      metadata, never raw financial fields.
- [x] Enforce the 100 MB input cap before decoding.

Files: `MonMon/Backup/MonMonBackupValidator.swift`,
`MonMonTests/Backup/MonMonBackupValidatorTests.swift`, project file.

## Task 3: Export the complete current store

- [x] Start with an in-memory-store test containing every model type.
- [x] Fetch all records using a dedicated context and map every stored field.
- [x] Capture only approved logical preferences, including statement mappings.
- [x] Prove export does not mutate the store or owner defaults.

Files: `MonMon/Backup/MonMonBackupService.swift`,
`MonMonTests/Backup/MonMonBackupServiceTests.swift`,
`MonMon/Transactions/PendingTransactionCapture.swift`, project file.

## Task 4: Restore authoritatively with recovery

- [x] Start with replacement, insertion, deletion, preference, recovery, and
      rollback tests.
- [x] Create the protected/atomic recovery snapshot before any mutation.
- [x] Update/insert/delete all model types by UUID and save once.
- [x] Restore preferences only after store save; expose recovery availability.
- [x] Prove failed validation/recovery/save leaves current data untouched.

Files: service and service tests from Task 3.

## Task 5: Add the Settings backup/restore flow

- [x] Add accessible export, import, preview, destructive confirmation,
      progress, success/failure, and Restore Previous Data states.
- [x] Use security-scoped file access and stop access in every path.
- [x] Require authentication when app lock is enabled.
- [x] Warn that exported JSON is readable and that CloudKit sync may propagate
      restored state.

Files: `MonMon/Backup/BackupRestoreView.swift`,
`MonMon/Settings/SettingsView.swift`, resource catalogue, project file.

## Task 6: Review and verification

- [x] Run code-quality, simplification, and security review.
- [x] Run focused and full macOS tests.
- [x] Run recursive Swift format lint.
- [x] Run compile-only iOS SDK build.
- [x] Commit final review-only corrections and report branch status.
- [x] Do not merge, push, or install on iPhone without explicit owner request.

---

# Roadmap: Budget and Goals

## Budget Core — current branch

- [x] Seed the standard six jars with a 55/10/10/10/10/5 allocation.
- [x] Protect Savings and Investment from deletion while allowing rename and resize.
- [x] Let the owner add, edit, and delete custom jars without exceeding 100%.
- [x] Persist configurable expense-category-to-jar mappings.
- [x] Forecast monthly income from recurring income rules.
- [x] Redistribute actual income, including bonuses, using the current percentages.
- [x] Route savings deposits to Savings and Gold/Fund cost basis to Investment.
- [x] Add an accessible Plan-vs-Actual Budget root destination.
- [x] Include budget records in complete backup and restore.
- [x] Pass focused/full tests, format lint, and compile-only iPhoneOS build.

## Goal Envelopes — completed on feature branch

- [x] Add a CloudKit-compatible goal model for Home, Vehicle, Trip, and Custom.
- [x] Treat earmarked goal money as an overlay, never a second asset or transaction.
- [x] Fund each goal from Savings, Investment, or another selected jar.
- [x] Calculate required monthly contribution and forecast completion date.
- [x] Aggregate several goals against one jar without double-committing its monthly plan.
- [x] Warn when later income or jar edits make existing commitments exceed capacity.
- [x] Block deletion of a custom jar while a goal references it.
- [x] Add accessible Goal list, progress cards, and add/edit/delete flow inside Budget.
- [x] Include goals in complete backup/restore while preserving legacy compatibility.
- [x] Pass focused/full tests, format lint, review, and compile-only iPhoneOS build.

## Trip Workspace — after Goal Envelopes

- [ ] Give a trip separate saving and spending phases.
- [ ] Attach transactions to a trip while preserving their ordinary categories.
- [ ] Allow a trip transaction to override its category’s default jar.
- [ ] Show total trip budget plus food, accommodation, and transport breakdowns.

## Income Allocation Timeline — current branch

- [x] Freeze a versioned jar-allocation snapshot on every new income transaction.
- [x] Reconcile every snapshot exactly to its transaction plus unallocated remainder.
- [x] Preserve snapshots through income edits and transaction delete/undo.
- [x] Capture manual, recurring, imported, and pending-capture income paths.
- [x] Backfill old income once and mark it as estimated.
- [x] Add an accessible month-selectable timeline inside Budget.
- [x] Distinguish recurring, imported, and one-off income events.
- [x] Explain that historical splits may differ from the current Budget setup.
- [x] Include snapshots in complete backup/restore with legacy compatibility.
- [x] Pass focused/full tests, review, format lint, and compile-only iPhoneOS build.

## Remaining exploration

- [ ] Historical monthly snapshots and explicit rollover rules.
- [ ] Adaptive Coach — overspend warnings and reallocation suggestions.
- [ ] Validate whether coaching is useful before adding notifications or automation.
