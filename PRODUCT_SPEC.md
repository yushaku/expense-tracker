# Expense Tracker — Product Specification v3

> Ứng dụng quản lý tài chính cá nhân, triển khai theo hướng iPhone-first; đồng bộ Apple và AI advisor được bổ sung theo từng giai đoạn.

**Status:** Approved · **Version:** 3.0 · **Updated:** 2026-08-17

## 1. Product outcome

Người dùng có thể ghi nhận thu, chi, chuyển tiền và hiểu dòng tiền của mình một cách đáng tin cậy. Dữ liệu tài chính phải chính xác, có thể kiểm toán, hoạt động offline và không phụ thuộc AI.

Vietnamese is used for UI copy and user-visible validation. English is used for code, schemas, protocols, and engineering documentation.

## 2. Delivery boundaries

| Phase | Clients | Storage and scope |
|---|---|---|
| **1 — MVP** | iPhone only (Expo React Native) | One local SQLite database; wallets, income, expense, transfer, ledger, dashboard, onboarding, JSON backup |
| **1.5** | iPhone only | Budget, investment, recurring transactions, native receipt OCR |
| **2** | iPhone + Mac Expo Web wrapper | CloudKit/iCloud sync, managed receipt assets, multi-currency |
| **3** | iPhone + Mac Electron | Local MCP server over the synced store; CKShare family sharing |

Phase 1 explicitly excludes Mac, Expo Web, Electron, MCP, CloudKit, shared databases, and family sharing. Phase 2 Mac is an Expo Web wrapper. Electron and MCP start only in Phase 3.

## 3. Product principles

- Offline-first: every Phase 1 workflow completes without a network.
- Ledger-first: balances and reports derive from active ledger entries, never mutable cached balances.
- Exact money: monetary values are signed 64-bit integer minor units plus ISO 4217 currency; JavaScript `number` and SQL `REAL` are forbidden for money.
- Immutable financial history: correction uses update operations that preserve audit history, or void-and-recreate when wallet/currency/transfer legs change.
- One domain implementation: business rules, validation, schedules, money arithmetic, and operation construction live in `packages/domain`.
- Progressive trust: AI is optional, Phase 3 only, read-only by default, bounded, auditable, and idempotent.
- Apple-native privacy: private CloudKit databases and CKShare; no custom family backend.

## 4. Functional scope

### Phase 1

- Create and manage cash, bank, e-wallet, and credit-card wallets.
- Record income and expense; update allowed descriptive fields/amount; void without destructive deletion.
- Transfer atomically between wallets with two balanced ledger legs.
- Dashboard: assets, credit-card debt, net worth, cash flow, category totals.
- Vietnamese onboarding with optional records marked `isSample = 1`.
- Full versioned JSON backup and validated restore.

### Phase 1.5

- Category/wallet budgets, investments, deterministic recurring generation, and missed-period catch-up.
- Receipt capture and OCR using iOS Vision/VisionKit through an Expo native module; user confirmation is mandatory.

### Phase 2

- CloudKit operation sync for every syncable entity, including `LedgerEntry` and receipt assets.
- Expo Web wrapper for Mac; no Electron and no MCP.
- Multi-currency with immutable transaction-time exchange-rate snapshots.

### Phase 3

- Electron Mac client using `packages/domain` and a local projection of synced CloudKit data.
- MCP server with bounded reads and opt-in audited writes.
- Family sharing via Apple `CKShare`, scoped per shared wallet/family zone.

## 5. Architecture contract

```text
apps/iphone (Phase 1+) ─┐
apps/mac-web (Phase 2+) ├─> packages/domain ─> repositories/operation log
apps/mac-electron (P3) ─┤                         │
apps/mcp-server (P3) ───┘                    SQLite / CloudKit adapter
```

`packages/domain` is the only owner of money types, entity types, invariants, ledger posting, recurring schedules, and commands. UI and MCP adapters may not reimplement these rules.

## 6. Canonical data rules

- IDs are UUID v4 strings; recurring occurrence IDs are UUID v5 derived from `scheduleId + dueLocalDate`.
- Money is `{ minorUnits: string, currency: string }` at JSON boundaries and 64-bit `INTEGER` in SQLite. Decimal input is parsed as text with currency scale and range checks.
- Every entity has `createdAtUtc`, `createdOffsetMinutes`, `updatedAtUtc`, and `updatedOffsetMinutes`. UTC fields are RFC 3339 instants ending in `Z`; offsets preserve user context.
- Financial entities and `LedgerEntry` have `status IN ('active','voided')`.
- Receipts use `Asset.id`; local paths are adapter-private and never persisted as domain identifiers.
- All writes emit immutable `Operation` rows. A global `IdempotencyRecord(operation, clientRequestId)` stores canonical payload hash and result permanently for financial writes.

The complete schema and constraints are normative in [docs/system/01-data-model.md](docs/system/01-data-model.md).

## 7. Accounting

For non-credit wallets, balance is the sum of signed active ledger entries. For a credit card:

```text
debt = sum(active expense minor units posted to card)
     - sum(active payment minor units posted to card)
availableCredit = creditLimitMinor - debt
netWorth = nonCreditAssets + investmentValue - creditCardDebt
```

Purchases increase debt; payments reduce debt. Credit limits are not assets. A transfer creates two legs in one SQL transaction and one immutable transfer operation.

## 8. Sync and conflict policy

Phase 2 synchronizes immutable operations, then deterministically rebuilds projections. Transfers and their ledger legs are never merged with last-writer-wins. Duplicate operation IDs are ignored; operation payload mismatch is quarantined. Metadata may use field-level merge only where documented. Tombstones/void operations are retained. CloudKit subscriptions and change tokens drive incremental sync; token expiration triggers a zone rescan.

## 9. MCP contract

Phase 3 MCP runs locally over stdio. `EXPENSE_MCP_READONLY` defaults to `true`. Every tool has valid JSON `inputSchema` and `outputSchema`, requires `walletId` where wallet scope matters, returns `structuredContent`, and mirrors it as text for compatibility. Domain/tool failures are successful JSON-RPC tool responses with `isError: true`; JSON-RPC errors are reserved for protocol failures.

Every write tool—including add, update, void, transfer, budget, investment, and recurring writes—requires `clientRequestId` and accepts `dryRun`. Committed MCP writes create an `AuditLog`. Read requests enforce query length, page size, cursor pagination, and timeout limits.

## 10. Security and privacy

- iOS Data Protection, least-privilege file permissions, Keychain secrets, and encrypted CloudKit transport/storage are required.
- Face ID is a privacy/convenience gate, not an authorization boundary; OS sandbox and CloudKit identity/permissions enforce access.
- Logs must redact amounts, notes, OCR text, receipt data, CloudKit tokens, and filesystem paths.
- MCP has no network listener, inherits local-user permissions, and remains read-only unless explicitly enabled.

## 11. Acceptance criteria

- Phase boundaries match Section 2 with no hidden dependency on a later client/service.
- Every financial write is atomic, idempotent, audited where required, and preserves ledger invariants.
- Randomized ledger tests prove balances; transfer tests prove two-leg conservation; credit-card tests prove debt and available-credit formulas.
- All money round-trips exactly at supported currency scales and rejects overflow/fractional minor units.
- Backup/restore round-trips all entities, assets, settings, audit logs, operations, and recurring state.
- Recurring generation is deterministic across relaunch, timezone changes, missed periods, leap years, and month ends.
- Sync convergence tests cover duplicate delivery, reordering, offline concurrent edits, transfer atomicity, tombstones, and token reset.
- MCP contract tests verify schemas, `structuredContent`, `isError`, read-only default, dry-run non-mutation, audit logs, limits, pagination, and idempotency.
- Accessibility, Vietnamese copy, offline behavior, migration, restore, and privacy checks pass on supported devices.

## 12. Definition of done

A phase is done only when its in-scope acceptance criteria pass; schema and docs match shipped behavior; migrations work from every released version and rollback is documented; backups made by the previous version restore; telemetry/logging contains no sensitive content; and release builds pass unit, integration, end-to-end, accessibility, and manual recovery tests. Deferred work is named in the next phase, never represented as implemented.

## 13. Testing and migration policy

Use domain unit/property tests, SQLite integration tests with foreign keys enabled, device E2E tests, backup fixtures, CloudKit simulator/sandbox convergence tests, and MCP protocol tests. CI runs schema linting and link/terminology checks.

Migrations are ordered, transactional, forward-only in production, and recorded in `schema_migrations`. Before a destructive rewrite, create and verify a backup. Additive compatibility spans at least one released version; CloudKit record changes use versioned decoders. Failed migrations roll back entirely and leave the prior database usable.

## 14. Source of truth

- Phase scope: `docs/phases/`
- Schema/accounting: `docs/system/01-data-model.md` and `03-ledger.md`
- Sync/MCP/security/backup contracts: corresponding `docs/system/` pages
- Feature behavior: `docs/features/`
- Review traceability: `docs/REVIEW_RESPONSE.md`
