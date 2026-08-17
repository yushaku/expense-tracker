# Phase 2 — iCloud Sync and Mac Web

## Goal

Synchronize the Apple-only dataset across devices and add a Mac Expo Web wrapper while preserving offline-first behavior and ledger integrity.

## In scope

- CloudKit private-zone operation sync for all entities, every `LedgerEntry`, tombstones, recurring state, settings, rates, and managed receipt assets.
- iPhone plus Mac Expo Web wrapper using the shared `packages/domain` contract.
- Incremental change tokens, outbox/inbox, retry, account-state UI, rebuild/recovery.
- Multi-currency with wallet currency and immutable transaction-time rate snapshots.

## Out of scope

Electron, MCP, CKShare/family, custom backend, web accounts, and record-level LWW for financial data.

## Acceptance criteria

- Two offline clients converge after reordered/duplicate delivery without duplicated financial effects.
- Transfer operation and both ledger legs apply atomically; concurrent edits never silently overwrite amounts.
- Receipt asset bytes and metadata converge and verify by hash.
- Expired tokens, quota, partial upload, account switch, and clean-device rebuild recover safely.
- Mac deliverable is the Expo Web wrapper; Electron/MCP dependencies are absent.

## Definition of done

CloudKit sandbox/device matrix, convergence/property, migration, backup, privacy, and accessibility tests pass; sync state is observable and recoverable in Vietnamese UI.
