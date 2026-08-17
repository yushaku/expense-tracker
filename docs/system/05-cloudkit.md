# System: CloudKit Sync (Phase 2)

CloudKit begins in Phase 2. Phase 1 remains a single iPhone SQLite database with backup/restore only. Phase 2 adds iPhone and Mac Expo Web clients; Phase 3 clients reuse this sync contract.

## Storage model

- Private database: one custom zone per user-owned dataset.
- Shared database: Phase 3 CKShare zones only.
- Records: immutable `Operation`, entity projections, every `LedgerEntry`, `Asset` metadata/CKAsset, settings, budgets, investments, recurring rules/occurrences, exchange-rate snapshots, and tombstones.
- Local SQLite remains the queryable projection and outbox/inbox store.

Every record carries stable ID, schema version, operation ID, UTC instant, offset minutes, actor/device ID, and payload hash. Receipt files are managed assets addressed by `Asset.id`; CKAsset upload/download validates byte count and SHA-256.

## Sync loop

1. Commit local operation and projection atomically; mark outbox pending.
2. Upload assets required by the operation, then immutable operation records.
3. Fetch zone changes using a persisted server change token.
4. Deduplicate by operation ID; verify hash and schema version.
5. Apply operations transactionally through `packages/domain` and rebuild affected projections/ledger.
6. Persist the new token only after the whole batch commits.

Retries use capped exponential backoff with jitter and honor CloudKit retry hints. Expired tokens trigger a full zone enumeration without deleting unsynced local operations.

## Conflict resolution

Financial state is operation-based, not last-writer-wins.

- Create/update/void operations are immutable and deterministically ordered by causal dependency, then `(createdAtUtc, operationId)` only as a tie-breaker.
- Duplicate ID + same hash is idempotent; same ID + different hash is quarantined and surfaced.
- A transfer is one logical operation containing both wallet effects; both ledger legs apply in one local transaction or neither does.
- Concurrent incompatible edits are retained and flagged for user resolution; no silent amount/wallet overwrite.
- Void dominates prior active projection but does not erase history. Later edits to a voided entity are rejected.
- Non-financial metadata may use documented field-level merge; raw record-level LWW is not used for financial operations.

## Identity and sharing

CloudKit account identity and zone permissions control access. Phase 3 family sharing uses Apple CKShare invitations, participant permissions, shared database scopes, and revocation. No custom backend, password system, or home-grown ACL exists.

## Recovery and observability

Sync state displays pending count, last successful instant, and Vietnamese actionable errors. Logging records record type/count, duration, retry class, and redacted codes only. Users can retry, export a full backup, reset a local projection after backup, and rebuild from verified CloudKit operations.

## Acceptance tests

- Two clients converge under duplicate, reordered, delayed, and offline delivery.
- Ledger entries and assets converge with their source entities.
- Concurrent transfer/edit/void sequences preserve conservation and history.
- Token expiration, partial asset failure, quota, account switch, and CKShare revoke recover safely.
- A clean device rebuild equals the originating device’s reconciled ledger and hashes.
