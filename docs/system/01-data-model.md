# System: Canonical Data Model

This document is normative. SQLite uses `snake_case`; TypeScript uses equivalent `camelCase` names. All entities include creation/update instant and offset fields. Syncable rows also include `operation_id`/version metadata in Phase 2.

## Shared types

```typescript
type MinorUnits = bigint; // serialize as base-10 string in JSON
type Money = { minorUnits: string; currency: ISO4217 };
type InstantWithOffset = { utc: string; offsetMinutes: number };
type Status = 'active' | 'voided';
```

Rules:

- SQLite money columns are `INTEGER` and checked for valid sign/range. SQL `REAL`, JS `number`, and binary floats are forbidden for money and rates.
- Quantity and FX rates use scaled integers: `quantityAtomic` plus `quantityScale`; `rateNumerator/rateDenominator` or decimal strings at boundaries.
- `*_at_utc` is an RFC 3339 UTC instant ending `Z`; `*_offset_minutes` is `[-840, 840]`.
- IDs are non-empty UUID strings. Currency is an uppercase, supported three-letter ISO 4217 code.
- Categories are rows, not an application enum; seeded stable IDs have Vietnamese labels and may be archived but not removed while referenced.

## Entities

| Entity                 | Phase | Required domain fields beyond common timestamps                                                                                                |
| ---------------------- | ----: | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `Wallet`               |     1 | `id`, `name`, `type`, `currency`, `creditLimitMinor`, `status`, `isSample`                                                                     |
| `Category`             |     1 | `id`, `kind`, `labelVi`, `status`, `isSystem`                                                                                                  |
| `Expense`              |     1 | `id`, `walletId`, `categoryId`, `amountMinor`, `currency`, occurred instant/offset, `status`, `merchant`, `note`, `receiptAssetId`, `isSample` |
| `Income`               |     1 | same shape with optional `categoryId/source`; `status`, `isSample`                                                                             |
| `Transfer`             |     1 | `id`, `fromWalletId`, `toWalletId`, `amountMinor`, `currency`, occurred instant/offset, `status`, `isSample`                                   |
| `LedgerEntry`          |     1 | `id`, `walletId`, `sourceType`, `sourceId`, `entryKind`, `signedMinor`, `currency`, occurred instant/offset, `status`                          |
| `Asset`                |     1 | `id`, `kind`, `mediaType`, `byteCount`, `sha256`, `managedName`, `status`; local path is not a domain field                                    |
| `Setting`              |     1 | `key`, `valueJson`, timestamps                                                                                                                 |
| `Operation`            |     1 | `id`, `kind`, `entityType`, `entityId`, `payloadJson`, `payloadHash`, `actorId`, timestamps                                                    |
| `IdempotencyRecord`    |     1 | `operation`, `clientRequestId`, `payloadHash`, `resultJson`, `createdAtUtc`; no expiry for financial writes                                    |
| `AuditLog`             |     1 | `id`, `actorType`, `actorId`, `action`, `entityType`, `entityId`, `requestId`, `outcome`, redacted details, timestamps                         |
| `Budget`               |   1.5 | category/wallet scope, `limitMinor`, currency, period and local anchor, `status`                                                               |
| `Investment`           |   1.5 | type, currency, `costBasisMinor`, `currentValueMinor`, scaled quantity, valuation instant/offset, `status`                                     |
| `RecurringRule`        |   1.5 | template, frequency, interval, anchor local date/day policy, timezone, next due, catch-up policy, `status`                                     |
| `ExchangeRateSnapshot` |     2 | pair, integer numerator/denominator, source, observed instant/offset                                                                           |
| `SyncState`            |     2 | zone, change token, retry state, timestamps                                                                                                    |
| `ShareReference`       |     3 | CKShare record name/zone, scope entity, permission, status                                                                                     |

## Core SQLite DDL

All production connections execute `PRAGMA foreign_keys = ON`. The migration contains equivalent constraints for every table; abbreviated nullable descriptive columns do not weaken required financial fields.

```sql
CREATE TABLE wallets (
  id TEXT PRIMARY KEY NOT NULL CHECK (length(id) > 0),
  name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
  type TEXT NOT NULL CHECK (type IN ('cash','bank','ewallet','credit_card')),
  currency TEXT NOT NULL CHECK (length(currency) = 3 AND currency = upper(currency)),
  credit_limit_minor INTEGER NOT NULL DEFAULT 0 CHECK (
    (type = 'credit_card' AND credit_limit_minor > 0) OR
    (type != 'credit_card' AND credit_limit_minor = 0)
  ),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','voided')),
  is_sample INTEGER NOT NULL DEFAULT 0 CHECK (is_sample IN (0,1)),
  created_at_utc TEXT NOT NULL CHECK (created_at_utc GLOB '*Z'),
  created_offset_minutes INTEGER NOT NULL CHECK (created_offset_minutes BETWEEN -840 AND 840),
  updated_at_utc TEXT NOT NULL CHECK (updated_at_utc GLOB '*Z'),
  updated_offset_minutes INTEGER NOT NULL CHECK (updated_offset_minutes BETWEEN -840 AND 840)
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('expense','income')),
  label_vi TEXT NOT NULL CHECK (length(trim(label_vi)) > 0),
  status TEXT NOT NULL CHECK (status IN ('active','archived')),
  is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0,1)),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL,
  UNIQUE(kind, label_vi)
);

CREATE TABLE assets (
  id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('receipt')),
  media_type TEXT NOT NULL CHECK (media_type LIKE 'image/%'),
  byte_count INTEGER NOT NULL CHECK (byte_count > 0),
  sha256 TEXT NOT NULL CHECK (length(sha256) = 64),
  managed_name TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('active','deleted')),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL
);

CREATE TABLE expenses (
  id TEXT PRIMARY KEY NOT NULL,
  wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  currency TEXT NOT NULL CHECK (length(currency) = 3),
  occurred_at_utc TEXT NOT NULL CHECK (occurred_at_utc GLOB '*Z'),
  occurred_offset_minutes INTEGER NOT NULL CHECK (occurred_offset_minutes BETWEEN -840 AND 840),
  merchant TEXT CHECK (merchant IS NULL OR length(merchant) <= 120),
  note TEXT CHECK (note IS NULL OR length(note) <= 1000),
  receipt_asset_id TEXT REFERENCES assets(id) ON DELETE SET NULL,
  status TEXT NOT NULL CHECK (status IN ('active','voided')),
  is_sample INTEGER NOT NULL DEFAULT 0 CHECK (is_sample IN (0,1)),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL
);

CREATE TABLE transfers (
  id TEXT PRIMARY KEY NOT NULL,
  from_wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  to_wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  currency TEXT NOT NULL CHECK (length(currency) = 3),
  occurred_at_utc TEXT NOT NULL, occurred_offset_minutes INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','voided')),
  is_sample INTEGER NOT NULL DEFAULT 0 CHECK (is_sample IN (0,1)),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL,
  CHECK (from_wallet_id <> to_wallet_id)
);

CREATE TABLE ledger_entries (
  id TEXT PRIMARY KEY NOT NULL,
  wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  source_type TEXT NOT NULL CHECK (source_type IN ('expense','income','transfer','opening_balance','refund')),
  source_id TEXT NOT NULL,
  entry_kind TEXT NOT NULL CHECK (entry_kind IN ('expense','income','transfer_out','transfer_in','opening_balance','refund')),
  signed_minor INTEGER NOT NULL CHECK (signed_minor != 0),
  currency TEXT NOT NULL CHECK (length(currency) = 3),
  occurred_at_utc TEXT NOT NULL, occurred_offset_minutes INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','voided')),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL,
  UNIQUE(source_type, source_id, entry_kind, wallet_id)
);

CREATE TABLE operations (
  id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
  payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
  payload_hash TEXT NOT NULL CHECK (length(payload_hash) = 64),
  actor_id TEXT NOT NULL,
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL,
  UNIQUE(entity_type, entity_id, id)
);

CREATE TABLE idempotency_records (
  operation TEXT NOT NULL,
  client_request_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL CHECK (length(payload_hash) = 64),
  result_json TEXT NOT NULL CHECK (json_valid(result_json)),
  created_at_utc TEXT NOT NULL, created_offset_minutes INTEGER NOT NULL,
  updated_at_utc TEXT NOT NULL, updated_offset_minutes INTEGER NOT NULL,
  PRIMARY KEY(operation, client_request_id)
);
```

`income`, budgets, investments, recurring rules, settings, and audit logs use the same `NOT NULL`, `CHECK`, FK, status, and timestamp conventions. No financial parent is cascade-deleted.

## Required indexes

```sql
CREATE INDEX idx_expenses_wallet_status_time ON expenses(wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_expenses_category_status_time ON expenses(category_id, status, occurred_at_utc, id);
CREATE INDEX idx_income_wallet_status_time ON income(wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_transfers_from_status_time ON transfers(from_wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_transfers_to_status_time ON transfers(to_wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_ledger_wallet_status_time ON ledger_entries(wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_ledger_source ON ledger_entries(source_type, source_id);
CREATE INDEX idx_operations_entity_time ON operations(entity_type, entity_id, created_at_utc, id);
CREATE INDEX idx_audit_request_time ON audit_logs(request_id, created_at_utc);
CREATE UNIQUE INDEX idx_recurring_occurrence ON recurring_occurrences(rule_id, due_local_date);
```

## Idempotency

Canonicalize validated input (sorted keys, normalized strings, monetary strings, UTC timestamps), hash with SHA-256, and look up `(operation, clientRequestId)` inside the write transaction. Same hash returns stored result; a different hash returns `IDEMPOTENCY_CONFLICT`. Financial keys never expire. Dry-runs neither create nor consume keys.

## Lifecycle and deletion

Financial records, ledger rows, operations, and audit logs are retained. Users void financial records and archive referenced configuration. Assets use a tombstone followed by garbage collection only after no active reference, backup retention, or pending sync depends on them.

## Migration policy

Migrations are numbered, transactional, repeatably tested from every released fixture, and recorded with checksum in `schema_migrations`. Rebuild-table migrations reapply FKs, checks, uniques, and indexes and run `foreign_key_check` plus ledger reconciliation before commit.
