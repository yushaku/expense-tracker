# Feature: Sync

## Phase behavior

- Phase 1/1.5: no live sync. Full backup/restore is available; CSV is only a lossy interchange format.
- Phase 2: CloudKit operation sync across iPhone and Mac Expo Web wrapper.
- Phase 3: Electron uses the same sync contract; CKShare adds family zones.

## Synced scope

Every source entity, `LedgerEntry`, category, budget, investment, recurring rule/occurrence, setting, exchange-rate snapshot, immutable operation/tombstone, managed asset metadata, and receipt CKAsset is synchronized. Device secrets and ephemeral change tokens are not portable data.

## UX

Display “Đã đồng bộ”, “Đang chờ đồng bộ”, last success instant, pending count, account/quota/permission errors, and retry/rebuild actions. Never claim success before assets and operation batches verify and the local transaction commits.

## Integrity

Transfers sync as one immutable operation and rebuild two legs atomically; financial conflicts are never record-level LWW. Deduplicate by operation ID+hash. Cursor/token reset, offline edits, duplicate/reordered changes, asset failure, account switch, and CKShare revocation must preserve local unsynced work or surface explicit recovery.

Detailed algorithms and tests are normative in `docs/system/05-cloudkit.md`.
