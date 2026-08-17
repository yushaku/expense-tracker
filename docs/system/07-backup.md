# System: Backup and Restore

## Scope

A full backup contains every user-relevant and recovery-critical record:

- wallets, categories, income, expenses, transfers, and every ledger entry;
- budgets, investments, recurring rules and generated-occurrence state;
- managed receipt `Asset` metadata and binary files;
- settings, exchange-rate snapshots, sync/share references where portable;
- immutable operations, durable idempotency records, and audit logs.

Ephemeral cache, CloudKit change tokens, temporary OCR images, and device secrets are excluded. The manifest says which device-local sync state must be recreated.

## Format

Use a versioned archive, e.g. `expense-tracker-backup-v3-2026-08-17T10-30-00Z.etbackup`, containing `manifest.json`, canonical JSONL tables, and `assets/<asset-id>`. Money is a base-10 minor-unit string; instants are UTC `Z` plus offset minutes. Manifest includes schema/app versions, creation instant, table counts, file sizes, and SHA-256 for every member.

The archive must not contain absolute paths. Optional user-selected encryption uses authenticated encryption and a Keychain-backed or user-supplied secret; never imply that a plain exported file is encrypted.

## Creation

1. Obtain a consistent SQLite read snapshot.
2. Reconcile ledger and validate foreign keys.
3. Stream canonical records and referenced assets with size limits.
4. Hash every member and write the manifest last.
5. Re-open and verify the completed archive before reporting “Sao lưu hoàn tất”.

## Restore

Restore is staged, never in-place:

1. Check archive/magic, schema compatibility, total/uncompressed sizes, safe relative paths, hashes, required entities, types, constraints, and duplicate IDs.
2. Import into a new temporary database with foreign keys enabled.
3. Run migrations, `foreign_key_check`, ledger reconciliation, transfer conservation, and asset verification.
4. Present a Vietnamese summary and require confirmation for replacement/merge choice.
5. Make a verified pre-restore backup, atomically swap databases/assets, then reopen and health-check.
6. On failure, retain the original database unchanged and remove only the known staging directory.

Merge restore replays immutable operations and durable idempotency keys; it never inserts rows ad hoc or uses timestamps as duplicate detection. Payload-hash conflicts require user resolution.

## Compatibility

- Current version restores the current and immediately previous released backup versions.
- Export remains forward-readable through documented versioned decoders.
- Unknown required fields fail safely; unknown optional fields are preserved where possible.
- CloudKit sync is paused during restore and resumes only after a new local consistency checkpoint.

## CSV

CSV is a lossy transaction export/import convenience, not a backup. It cannot represent ledger history, assets, operations, audit logs, recurring state, or settings and must never be presented as disaster recovery.

## Tests

Golden fixtures cover every supported version; round-trip equality covers all tables and asset hashes. Tests include corruption, truncation, zip bombs, path traversal, missing ledger legs/assets, integer boundaries, duplicate operations, disk-full, cancellation, and rollback after each restore stage.
