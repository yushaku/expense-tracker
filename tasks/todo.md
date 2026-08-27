# Tasks: Full Backup and Restore

## Task 0: Restore the baseline macOS quality gate

- [x] Guard the iOS-only `ShortcutsLink` on macOS.
- [x] Run focused/full macOS tests to prove the baseline compiles.
- [x] Commit the prerequisite independently.

Files: `MonMon/Settings/SettingsView.swift`

## Task 1: Define and encode the backup document

- [x] Start with failing round-trip and canonical-scalar tests.
- [x] Add format/version metadata, payload DTOs for all 13 models, preferences,
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

- [ ] Run code-quality, simplification, and security review.
- [ ] Run focused and full macOS tests.
- [ ] Run recursive Swift format lint.
- [ ] Run compile-only iOS SDK build.
- [ ] Commit final review-only corrections and report branch status.
- [ ] Do not merge, push, or install on iPhone without explicit owner request.
