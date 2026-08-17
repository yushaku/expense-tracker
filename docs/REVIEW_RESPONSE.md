# v3 Documentation Review Response

This document maps all 84 findings from the v2 code review to the corrective contracts in the rewritten v3 documentation. “Fixed” includes findings resolved by removing the unsafe capability from an early phase and assigning it explicit later-phase gates.

## Critical

**Issue 1 — No authoritative Phase 1 database.** The old plan let iPhone and Mac databases diverge before sync existed. v3 makes Phase 1 iPhone-only with one app-local SQLite database and moves multi-device operation to CloudKit in Phase 2. **Fix:** `PRODUCT_SPEC.md` §§2, 4; `docs/phases/01-phase-1.md`; `docs/phases/03-phase-2.md`.

**Issue 2 — Contradictory Phase 1 Mac implementation.** v2 alternated among Expo Web, Electron, and a later Electron roadmap. v3 fixes the sequence: no Mac in Phase 1, Expo Web wrapper in Phase 2, and Electron only in Phase 3. **Fix:** `PRODUCT_SPEC.md` §2; `docs/README.md` Roadmap; `docs/phases/01-phase-1.md`, `03-phase-2.md`, `04-phase-3.md`.

**Issue 3 — Expo Web could not share the native SQLite file.** The architecture incorrectly assumed Expo Web and `better-sqlite3` could transparently use one file. v3 removes shared-file access: Phase 2 clients synchronize immutable operations through CloudKit, while the Phase 3 Electron client uses a synced local projection. **Fix:** `PRODUCT_SPEC.md` §§5, 8; `docs/system/02-architecture.md`; `docs/system/05-cloudkit.md`.

**Issue 4 — Duplicated domain logic.** Ledger and validation logic appeared separately in mobile and MCP code. v3 makes `packages/domain` the sole owner of money, commands, schedules, invariants, and ledger posting; all clients and MCP use adapters around it. **Fix:** `PRODUCT_SPEC.md` §§3, 5; `docs/system/02-architecture.md`; `docs/features/04-mcp-server.md`.

**Issue 5 — Undefined concurrent desktop/MCP writes.** v2 lacked WAL, locking, migration ownership, and compatibility rules. v3 postpones both Electron and MCP to Phase 3, routes writes through one domain/write coordinator, and specifies WAL, busy timeout, transactional migration ownership, schema checks, and recovery. **Fix:** `docs/system/02-architecture.md`; `docs/system/04-mcp-protocol.md`; `docs/phases/04-phase-3.md`.

**Issue 6 — Money used JavaScript `number`.** v3 uses signed 64-bit SQLite integer minor units, `bigint` internally, and base-10 strings at JSON boundaries; binary floats and SQL `REAL` are forbidden for money and rates. **Fix:** `PRODUCT_SPEC.md` §§3, 6; `docs/system/01-data-model.md` Shared types; `docs/features/11-multi-currency.md`.

**Issue 7 — Incomplete ledger schema.** `LedgerEntry.status`, timestamps, ordering, and opening-balance references were absent. v3 defines all fields, includes `opening_balance` and `refund` source/entry kinds, constraints, uniqueness, timestamps, offsets, and required indexes. **Fix:** `docs/system/01-data-model.md` Entities, Core SQLite DDL, Required indexes; `docs/system/03-ledger.md`.

**Issue 8 — Inconsistent credit-card signs and formulas.** v3 explicitly defines debt as card expenses minus payments, available credit as limit minus debt, and excludes credit limits from assets; it also specifies purchases, payments, refunds, voids, overpayments, and disallowed transfer directions. **Fix:** `PRODUCT_SPEC.md` §7; `docs/system/03-ledger.md`; `docs/features/01-wallets.md`; `docs/features/03-dashboard.md`.

**Issue 9 — Broken credit-card sample query.** The invalid `status = 'available'` query was removed. v3 uses only `active`/`voided` financial statuses and defines card calculations from active entries with normative formulas and tests. **Fix:** `docs/system/01-data-model.md` Shared types and DDL; `docs/system/03-ledger.md`; `PRODUCT_SPEC.md` §11.

**Issue 10 — Race-prone credit-limit enforcement.** v3 requires limit and balance validation inside the same immediate SQL transaction as operation, source, and ledger writes, with rollback on invariant failure; imports, recurrence, sync, update, and void use the same domain command path. **Fix:** `docs/system/03-ledger.md`; `docs/system/02-architecture.md`; `PRODUCT_SPEC.md` §§5, 11.

**Issue 11 — Competing source and ledger truth.** v3 chooses immutable `Operation` rows as the synchronization authority and deterministic projections for source records and ledger entries; mismatched hashes are quarantined rather than independently merged. **Fix:** `PRODUCT_SPEC.md` §§6, 8; `docs/system/03-ledger.md`; `docs/system/05-cloudkit.md`.

**Issue 12 — CloudKit omitted ledger entries.** v3 explicitly synchronizes every `LedgerEntry` and the immutable operation that deterministically rebuilds it, with atomic transfer-leg application and clean-device rebuild tests. **Fix:** `PRODUCT_SPEC.md` §4 Phase 2; `docs/features/06-sync.md`; `docs/system/05-cloudkit.md`; `docs/phases/03-phase-2.md`.

## Data Model

**Issue 13 — No concrete SQL schema.** v3 adds normative SQLite DDL with affinities, `NOT NULL`, `CHECK`, FK, uniqueness, deletion restrictions, timestamp rules, and transaction requirements, plus conventions for the remaining tables. **Fix:** `docs/system/01-data-model.md` Core SQLite DDL, Required indexes, Lifecycle and deletion.

**Issue 14 — Unsafe fallback IDs.** The timestamp-plus-random fallback is removed; entity IDs use cryptographic UUID v4 and recurring occurrence IDs use deterministic UUID v5. **Fix:** `PRODUCT_SPEC.md` §6; `docs/system/01-data-model.md` Shared types; `docs/features/09-recurring.md` Rule model.

**Issue 15 — Unspecified idempotency scope.** v3 defines a global `IdempotencyRecord` keyed by `(operation, clientRequestId)` with canonical payload hash and stored result, checked within the write transaction. **Fix:** `PRODUCT_SPEC.md` §6; `docs/system/01-data-model.md` Idempotency; `docs/system/04-mcp-protocol.md`.

**Issue 16 — Idempotency expiry allowed delayed duplicates.** Financial idempotency records now persist without expiry; validated inputs are canonically normalized and hashed, identical retries return the stored result, and payload mismatches fail. **Fix:** `docs/system/01-data-model.md` Idempotency; `docs/system/04-mcp-protocol.md` Idempotency and writes.

**Issue 17 — Updates and voids lacked idempotency.** Every add, update, void, transfer, budget, investment, and recurring MCP write now requires `clientRequestId`; domain writes share the durable contract. **Fix:** `PRODUCT_SPEC.md` §9; `docs/features/04-mcp-server.md`; `docs/phases/04-phase-3.md`.

**Issue 18 — Update semantics were undefined.** v3 distinguishes in-place descriptive/amount corrections that preserve audit history from void-and-recreate when wallet, currency, or transfer legs change; all changes emit immutable operations and commit source/ledger/audit effects atomically. **Fix:** `PRODUCT_SPEC.md` §§3, 6; `docs/system/03-ledger.md`; `docs/features/02-expenses.md` Operations.

**Issue 19 — Transfer funds policy was unresolved.** v3 requires distinct wallets, positive exact minor units, matching currency in Phase 1, and wallet-type-specific funds/credit checks; cross-currency transfers become explicit conversion operations in Phase 2. **Fix:** `docs/features/01-wallets.md`; `docs/system/03-ledger.md`; `docs/features/11-multi-currency.md`.

**Issue 20 — Wallet deletion/archival was undefined.** Wallets with history are archived/voided and financial parents use `ON DELETE RESTRICT`; no cascade may orphan transactions, rules, budgets, assets, or sync operations. **Fix:** `docs/features/01-wallets.md`; `docs/system/01-data-model.md` Lifecycle and deletion.

**Issue 21 — Opening-balance correction was undefined.** v3 models opening balance as a ledger-backed operation and requires corrections to preserve history through an adjusting operation or void-and-recreate workflow, followed by reconciliation. **Fix:** `docs/system/03-ledger.md` Opening balances and correction; `docs/features/01-wallets.md` Accounting.

**Issue 22 — No reconciliation model.** v3 defines deterministic projection rebuild, integrity checks between operations/source rows/ledger legs, explicit adjustment and reconciliation records, quarantine rather than silent repair, and recovery tests. **Fix:** `docs/system/03-ledger.md` Reconciliation and repair; `docs/system/05-cloudkit.md` Rebuild and recovery; `PRODUCT_SPEC.md` §11.

**Issue 23 — `savings` conflicted with transfer accounting.** The fixed expense enum is replaced with FK-backed categories, and moving money to savings is explicitly a transfer rather than an expense; categories may describe true expenses but do not override accounting type. **Fix:** `docs/system/01-data-model.md` Shared types and Categories; `docs/features/02-expenses.md`; `docs/features/03-dashboard.md`.

**Issue 24 — `isSample` was absent from the model.** v3 adds `isSample` to canonical wallets and financial entities; sample creation/removal uses ordinary domain and ledger paths so cleanup cannot corrupt balances or touch user records. **Fix:** `docs/system/01-data-model.md` Entities and DDL; `docs/features/05-onboarding.md`; `docs/phases/01-phase-1.md`.

**Issue 25 — Receipt paths were not portable.** Domain records now reference managed `Asset.id`; paths remain adapter-private, while backup and CloudKit move metadata and bytes with hashes. **Fix:** `PRODUCT_SPEC.md` §6; `docs/system/01-data-model.md` Asset; `docs/features/10-ocr.md`; `docs/system/07-backup.md`.

**Issue 26 — Voiding destroyed receipt evidence.** v3 retains managed receipt assets with voided financial history and only removes protected temporary OCR material; asset deletion follows retention/reference rules rather than transaction void. **Fix:** `docs/features/10-ocr.md`; `docs/system/01-data-model.md` Lifecycle and deletion; `docs/system/06-security.md`.

**Issue 27 — Ambiguous time semantics.** v3 separates RFC 3339 UTC instants, stored offset minutes, and local calendar anchors/IANA zones for budget and recurrence semantics; every entity has creation/update instant and offset fields. **Fix:** `PRODUCT_SPEC.md` §6; `docs/system/01-data-model.md` Shared types; `docs/features/09-recurring.md`.

**Issue 28 — Fixed timezone blocked travel and migration.** v3 preserves each occurrence’s offset and each calendar rule’s IANA timezone, buckets reports by selected/preserved local context, and tests timezone/DST changes rather than hard-coding Ho Chi Minh City. **Fix:** `docs/system/01-data-model.md`; `docs/features/03-dashboard.md`; `docs/features/09-recurring.md`; `PRODUCT_SPEC.md` §11.

**Issue 29 — Indexes did not match queries.** v3 adds composite wallet/category/status/time/id indexes for expenses, income, transfers, ledger, operations, and audit, plus unique idempotency and recurring-occurrence keys. **Fix:** `docs/system/01-data-model.md` Required indexes and Idempotency.

**Issue 30 — Future ownership fields were absent.** v3 avoids premature custom identity columns and defines Phase 3 authority through CKShare zones/participants plus `ShareReference`, explicit wallet/share scope, actor attribution, and isolation of private records. **Fix:** `docs/system/01-data-model.md` Entities; `docs/features/12-family.md`; `docs/system/05-cloudkit.md`.

**Issue 31 — Budgets/investments could be hard-deleted.** v3 gives both entities lifecycle status and mandates archive/void semantics for referenced history. **Fix:** `docs/system/01-data-model.md` Entities and Lifecycle; `docs/features/07-budget.md`; `docs/features/08-investment.md`.

**Issue 32 — Net worth mishandled liabilities.** v3 defines `netWorth = nonCreditAssets + investmentValue - creditCardDebt`; credit limit and available credit are never assets. **Fix:** `PRODUCT_SPEC.md` §7; `docs/features/03-dashboard.md` Metrics; `docs/features/01-wallets.md` Accounting.

**Issue 33 — Investment model was too lossy.** v3 scopes Phase 1.5 to manual holdings with exact cost/value, scaled quantity, valuation timestamps, and history-preserving status, while requiring separate cash transactions for purchases/sales and clearly avoiding claims of full brokerage accounting. **Fix:** `docs/features/08-investment.md`; `docs/system/01-data-model.md` Entities; `docs/phases/02-phase-1.5.md`.

**Issue 34 — Multi-currency lacked transaction-time valuation.** v3 adds immutable `ExchangeRateSnapshot` records with rational/scaled rate, source, observed instant, currency scale, deterministic rounding, and explicit links from conversions and reports. **Fix:** `docs/features/11-multi-currency.md`; `docs/system/01-data-model.md` Entities; `PRODUCT_SPEC.md` §4 Phase 2.

## MCP

**Issue 35 — Business errors used JSON-RPC errors.** v3 reserves JSON-RPC errors for protocol failures and returns domain/tool failures as MCP tool results with `isError: true`. **Fix:** `PRODUCT_SPEC.md` §9; `docs/system/04-mcp-protocol.md`; `docs/phases/04-phase-3.md`.

**Issue 36 — Responses were text-encoded JSON only.** Every tool now declares `outputSchema`, returns validated `structuredContent`, and mirrors a concise text representation for compatibility. **Fix:** `PRODUCT_SPEC.md` §9; `docs/system/04-mcp-protocol.md` Tool contract; `docs/features/04-mcp-server.md`.

**Issue 37 — Invalid/incomplete tool schema.** The faulty example is replaced by strict schemas with required wallet scope, bounds, lengths, date/currency rules, enums/FKs, and `additionalProperties: false`. **Fix:** `docs/system/04-mcp-protocol.md` Schemas and validation; `docs/features/04-mcp-server.md` Contract.

**Issue 38 — Some writes lacked dry-run.** Every write, including update and void, accepts `dryRun`; preview performs validation but creates no domain, audit-commit, sync, or idempotency state. **Fix:** `PRODUCT_SPEC.md` §9; `docs/features/04-mcp-server.md` Writes; `docs/system/04-mcp-protocol.md`.

**Issue 39 — Read-only defaulted to false.** `EXPENSE_MCP_READONLY` now defaults to `true`, mutation requires explicit enablement, and Phase 1/2 contain no MCP at all. **Fix:** `PRODUCT_SPEC.md` §§2, 9; `docs/system/04-mcp-protocol.md`; `docs/phases/04-phase-3.md`.

**Issue 40 — Read-only annotations were insufficient.** v3 uses annotations as metadata only and mandates server-side mutation rejection, with contract tests proving default configuration cannot write. **Fix:** `docs/system/04-mcp-protocol.md` Authorization; `docs/features/04-mcp-server.md`; `docs/phases/04-phase-3.md` Acceptance criteria.

**Issue 41 — No confirmation/authorization policy.** v3 disallows autonomous unconfirmed writes, requires explicit server enablement and client approval expectations, records actor/origin/request attribution, and scopes family actions to wallet/share permission. **Fix:** `docs/system/04-mcp-protocol.md`; `docs/system/06-security.md`; `docs/phases/04-phase-3.md`.

**Issue 42 — MCP audit logging was postponed.** MCP is moved to Phase 3 and audit logging is a prerequisite: committed plus denied/failed mutation attempts create redacted `AuditLog` records. **Fix:** `PRODUCT_SPEC.md` §§2, 9; `docs/features/04-mcp-server.md`; `docs/system/06-security.md`; `docs/phases/04-phase-3.md`.

**Issue 43 — Advisor read surface was too weak.** v3 adds bounded transaction detail/search, transfers, balances, summaries/trends, budgets, investments, recurrence, reconciliation, and sync/freshness data, all derived through the domain layer. **Fix:** `docs/system/04-mcp-protocol.md` Read tools; `docs/features/04-mcp-server.md` Reads.

**Issue 44 — Offset pagination was unstable.** Read tools now use deterministic opaque cursor pagination over stable time/ID ordering with explicit page-size limits. **Fix:** `PRODUCT_SPEC.md` §9; `docs/system/04-mcp-protocol.md` Reads; `docs/phases/04-phase-3.md`.

**Issue 45 — Dynamic wallets duplicated a resource.** The mutable wallet resource is removed in favor of tool-based bounded reads with explicit freshness metadata; static resources are limited to suitable documentation/schema content. **Fix:** `docs/system/04-mcp-protocol.md` Tools and resources; `docs/features/04-mcp-server.md`.

**Issue 46 — MCP path expansion/validation was unsafe.** v3 requires an explicit canonical absolute database path, rejects ambiguous/symlink escape targets, validates ownership/permissions, and keeps raw DB access behind the desktop host/coordinator. **Fix:** `docs/system/04-mcp-protocol.md` Startup/configuration; `docs/system/06-security.md`; `docs/system/02-architecture.md`.

**Issue 47 — Manual MCP test was invalid.** The test procedure now invokes the built `.js` entry and performs the MCP initialization handshake before listing/calling tools; protocol contract tests replace the broken one-line sample. **Fix:** `docs/system/04-mcp-protocol.md` Launch and protocol test; `docs/features/04-mcp-server.md` Acceptance.

**Issue 48 — Database compatibility was not negotiated.** v3 defines a supported schema-version range at startup; MCP never migrates independently and returns an actionable incompatibility response while the owning app controls migrations. **Fix:** `docs/system/04-mcp-protocol.md` Startup compatibility; `docs/system/02-architecture.md`; `PRODUCT_SPEC.md` §13.

**Issue 49 — MCP reads had no limits.** v3 caps query text, page size, date range, output, and execution time; it uses field minimization and redacts receipt/path content. **Fix:** `docs/features/04-mcp-server.md` Reads; `docs/system/04-mcp-protocol.md` Limits; `PRODUCT_SPEC.md` §9.

## Sync

**Issue 50 — “LWW with vector clock” was contradictory.** v3 removes that claim and uses immutable operation IDs/hashes for financial convergence; only documented metadata may use field-level merge. **Fix:** `PRODUCT_SPEC.md` §8; `docs/system/05-cloudkit.md` Conflict policy.

**Issue 51 — Record-level LWW broke financial invariants.** Transfers and financial changes sync as immutable operation groups and rebuild projections atomically; source and ledger rows are never independently LWW-merged. **Fix:** `PRODUCT_SPEC.md` §8; `docs/features/06-sync.md` Integrity; `docs/system/05-cloudkit.md`.

**Issue 52 — Deletes/tombstones were absent.** v3 retains void/tombstone operations, defines retention and compaction constraints, handles stale-device replay, and uses zone rescan after token expiration. **Fix:** `PRODUCT_SPEC.md` §8; `docs/system/05-cloudkit.md`; `docs/phases/03-phase-2.md`.

**Issue 53 — Sync schema was incomplete.** The synchronized scope now explicitly includes all source entities, ledger entries, categories, budgets, investments, recurrence state, settings, rate snapshots, operations/tombstones, audit references, asset metadata, and receipt bytes. **Fix:** `docs/features/06-sync.md` Synced scope; `docs/system/05-cloudkit.md`; `docs/phases/03-phase-2.md`.

**Issue 54 — CloudKit schema deployment was unsafe.** v3 distinguishes development schema creation from production promotion, requires versioned decoders/additive rollout, and gates app release on production schema deployment and compatibility checks. **Fix:** `docs/system/05-cloudkit.md` Schema deployment; `PRODUCT_SPEC.md` §13.

**Issue 55 — CloudKit E2E claim was too broad.** v3 narrows claims to Apple transport/storage/account protections, identifies sensitive-field/asset protection choices, documents Keychain and reset behavior, and avoids promising blanket application E2E encryption. **Fix:** `docs/system/06-security.md` CloudKit; `docs/system/05-cloudkit.md` Security and recovery.

**Issue 56 — CloudKit recovery states were missing.** v3 specifies UI and recovery for missing/changed iCloud account, disabled service, quota, throttling, partial asset/batch failure, zone/token loss, revocation, key reset, and long-offline clients. **Fix:** `docs/system/05-cloudkit.md` Failure/recovery; `docs/features/06-sync.md` UX and Integrity; `docs/phases/03-phase-2.md` Acceptance.

**Issue 57 — MCP could read stale Mac data.** Phase 3 MCP exposes sync status and freshness metadata and reads the Electron host’s synced projection; responses surface pending/error state instead of implying freshness. **Fix:** `docs/system/04-mcp-protocol.md` Read tools; `docs/features/06-sync.md` UX; `docs/system/02-architecture.md`.

**Issue 58 — Family model conflicted with CloudKit.** v3 removes custom email/password, OAuth, invite-code, and backend authority; family sharing uses CKShare, Apple participants, custom/shared zones, and system invitation flows. **Fix:** `PRODUCT_SPEC.md` §§3, 4; `docs/features/12-family.md`; `docs/phases/04-phase-3.md`.

**Issue 59 — Family permissions were inconsistent.** CKShare participant identity and read/write permissions are authoritative, local references never grant access, and application operations verify share/wallet scope with actor attribution. **Fix:** `docs/features/12-family.md` Model and Operations; `docs/system/06-security.md` Authorization.

**Issue 60 — Family leave/delete semantics were unsafe.** v3 distinguishes owner deletion, supported ownership transfer, participant leave, and revocation; pending unauthorized writes stop and shared local projections/assets are removed under a confirmed cache policy without deleting owner data. **Fix:** `docs/features/12-family.md` Operations and Acceptance; `docs/system/05-cloudkit.md` CKShare recovery.

## Feature

**Issue 61 — Tesseract.js was unvalidated on React Native.** v3 explicitly rejects Tesseract.js for this client and selects on-device Apple Vision/VisionKit through a maintained Expo native module, with mandatory user confirmation and device tests. **Fix:** `docs/features/10-ocr.md`; `docs/phases/02-phase-1.5.md`.

**Issue 62 — Recurring generation had no dependable owner.** v3 makes the foreground/start domain scheduler the Phase 1.5 owner; after sync, deterministic occurrence IDs and atomic uniqueness make any device retry safe rather than relying on iOS cron execution. **Fix:** `docs/features/09-recurring.md` Scheduling; `docs/system/05-cloudkit.md`.

**Issue 63 — Missed periods and calendar edges were mishandled.** v3 enumerates every due local date, supports explicit catch-up policy and batching, and defines month-end, days 29–31, leap-year, timezone/DST, edit, pause, and resume behavior. **Fix:** `docs/features/09-recurring.md` Scheduling and Update; `PRODUCT_SPEC.md` §11.

**Issue 64 — Recurring deduplication was weak.** Occurrences now use deterministic UUID v5 from rule, due date, and template version plus a unique `(rule_id, due_local_date)` constraint and stable request ID, committed atomically with the transaction. **Fix:** `docs/features/09-recurring.md` Rule model; `docs/system/01-data-model.md` Required indexes.

**Issue 65 — Budget periods were underspecified.** v3 defines weekly/monthly/yearly local-calendar periods with anchor/timezone, active-range uniqueness, exact inclusions/exclusions, integer utilization, and edge-case acceptance tests. **Fix:** `docs/features/07-budget.md`; `docs/system/01-data-model.md` Budget entity.

**Issue 66 — Notification permissions/scheduling were ignored.** v3 treats alerts as advisory, specifies permission denial and settings/timezone changes, deduplicates threshold notifications, recomputes from ledger state, and includes foreground/background/platform failure behavior. **Fix:** `docs/system/06-security.md` Permissions; `docs/features/07-budget.md`; `docs/features/05-onboarding.md` Acceptance.

**Issue 67 — Backup omitted major data.** The versioned archive now includes every canonical table, ledger/operation/audit/recurrence/sync state, categories/settings/rates, asset metadata, and receipt bytes, with manifest counts and hashes. **Fix:** `docs/system/07-backup.md` Archive contents; `PRODUCT_SPEC.md` §11.

**Issue 68 — Restore and merge semantics conflicted.** v3 separates transactional full restore from explicit merge/import workflows, requires preflight and backup, and forbids silently mixing the two. **Fix:** `docs/system/07-backup.md` Restore and import modes; `docs/features/06-sync.md` Phase behavior.

**Issue 69 — Backup checksum was underspecified.** v3 defines canonical JSONL bytes, per-member SHA-256 in a versioned manifest, covered-byte verification before mutation, and clarifies that hashes detect corruption while authenticated encryption protects tampering. **Fix:** `docs/system/07-backup.md` Format and integrity.

**Issue 70 — Backup encryption was vague/dated.** v3 specifies a versioned AES-256-GCM envelope with authenticated metadata, unique salt/nonce, documented KDF parameters, failure behavior, and no partial restore on authentication failure. **Fix:** `docs/system/07-backup.md` Encryption.

**Issue 71 — In-app automatic backups did not survive device loss.** v3 labels local snapshots as rollback only and requires user-selected Files/iCloud/external export for disaster recovery, with freshness/status surfaced to the user. **Fix:** `docs/system/07-backup.md` Storage and recovery; `docs/features/06-sync.md`.

**Issue 72 — CSV transfer representation was ambiguous.** v3 defines CSV as lossy interchange, uses explicit record type plus source/destination fields for transfers, documents omitted fidelity, and reserves full round trips for the versioned archive. **Fix:** `docs/system/07-backup.md` CSV; `docs/features/06-sync.md` Phase behavior; `docs/phases/01-phase-1.md`.

## Security

**Issue 73 — Face ID was mistaken for file authorization.** v3 explicitly calls Face ID a convenience/privacy gate and relies on OS sandbox, Data Protection, local-user permissions, and CloudKit identity for actual access control. **Fix:** `PRODUCT_SPEC.md` §10; `docs/system/06-security.md`; `docs/features/05-onboarding.md`.

**Issue 74 — SQLite side files and temporary artifacts were unprotected.** v3 applies protection/permissions and cleanup rules to DB, WAL, SHM, backups, exports, managed assets, logs, and OCR temporary files, not just the main database. **Fix:** `docs/system/06-security.md` Local storage; `docs/features/10-ocr.md`; `docs/system/07-backup.md`.

**Issue 75 — Future secrets had no plan.** v3 requires Keychain storage, least privilege, rotation/revocation, and redaction for CloudKit/service tokens and any later external-provider credentials; secrets never enter SQLite, logs, or backups. **Fix:** `docs/system/06-security.md` Secrets; `PRODUCT_SPEC.md` §10.

**Issue 76 — Unsupported security claims were overconfident.** v3 removes blanket claims about constant-time comparison, pinning, idempotency as replay prevention, GDPR compliance, and universal E2E; it states concrete controls, limits, and threat boundaries only. **Fix:** `docs/system/06-security.md` Threat model and claims; `PRODUCT_SPEC.md` §10.

**Issue 77 — Open banking/email forwarding was unplanned scope.** These integrations are removed from the committed v3 phases; any future addition requires a separate backend/provider, consent, token-custody, deduplication, privacy, and regulatory design before roadmap entry. **Fix:** `PRODUCT_SPEC.md` §§2, 4; `docs/phases/` scope boundaries; `docs/system/06-security.md` Future integrations.

**Issue 78 — Desktop packaging was missing.** Electron is deferred to Phase 3 and now has explicit sandboxed renderer/preload IPC, native-module ownership, code signing, notarization, entitlements, update, path migration, and MCP installation release gates. **Fix:** `docs/system/02-architecture.md` Desktop packaging; `docs/phases/04-phase-3.md` Acceptance.

**Issue 79 — Expo/native dependency strategy was missing.** v3 defines iPhone Expo prebuild/dev-client use for SQLite protection, biometrics, and the Vision/VisionKit module; Expo Go is not treated as the production runtime, while Mac Web and Electron remain separate phased adapters. **Fix:** `docs/system/02-architecture.md` Client/runtime strategy; `docs/features/10-ocr.md`; `docs/phases/02-phase-1.5.md`.

**Issue 80 — No acceptance criteria or definition of done.** v3 adds global observable acceptance criteria and a definition of done, then supplies phase- and feature-specific behavior, integrity, accessibility, recovery, and platform gates. **Fix:** `PRODUCT_SPEC.md` §§11–12; every `docs/phases/*.md`; feature Acceptance sections.

**Issue 81 — Testing was generic.** v3 explicitly requires property ledger tests, migrations, crash/rollback, concurrent writes, backup/asset round trips, sync convergence matrices, timezone/recurrence boundaries, MCP contracts, audit, privacy, accessibility, and device E2E. **Fix:** `PRODUCT_SPEC.md` §§11, 13; `docs/system/03-ledger.md`, `04-mcp-protocol.md`, `05-cloudkit.md`, `07-backup.md`.

**Issue 82 — No migration/version policy.** v3 defines ordered transactional forward migrations, `schema_migrations`, rollback-on-failure, prior-version backup compatibility, additive compatibility, CloudKit versioned decoders, and MCP schema-range checks. **Fix:** `PRODUCT_SPEC.md` §§12–13; `docs/system/01-data-model.md` Migration policy; `docs/system/04-mcp-protocol.md` Compatibility.

**Issue 83 — No observability/support diagnostics.** v3 adds redacted structured local logs, sync freshness/health, integrity and migration history, backup status, protocol diagnostics, and exportable support bundles that exclude financial content and secrets. **Fix:** `docs/system/06-security.md` Logging/diagnostics; `docs/system/05-cloudkit.md` Observability; `docs/system/07-backup.md` Status.

**Issue 84 — MVP scope was too large.** v3 reduces Phase 1 to one offline iPhone client and core accounting/backup, moves planning features to 1.5, sync/Mac Web/multi-currency to Phase 2, and Electron/MCP/family to Phase 3 with explicit exclusions and gates. **Fix:** `PRODUCT_SPEC.md` §§2, 4; `docs/README.md` Roadmap; all `docs/phases/*.md`.

## Summary

| Issue # | Category   | Status | Fix Location                             |
| ------: | ---------- | ------ | ---------------------------------------- |
|       1 | Critical   | Fixed  | `PRODUCT_SPEC.md` §2; Phase 1/2 docs     |
|       2 | Critical   | Fixed  | `PRODUCT_SPEC.md` §2; all phase docs     |
|       3 | Critical   | Fixed  | Architecture; CloudKit                   |
|       4 | Critical   | Fixed  | `PRODUCT_SPEC.md` §5; Architecture       |
|       5 | Critical   | Fixed  | Architecture; MCP protocol; Phase 3      |
|       6 | Critical   | Fixed  | Data model; Multi-currency               |
|       7 | Critical   | Fixed  | Data model; Ledger                       |
|       8 | Critical   | Fixed  | Ledger; Wallets; Dashboard               |
|       9 | Critical   | Fixed  | Data model; Ledger                       |
|      10 | Critical   | Fixed  | Ledger; Architecture                     |
|      11 | Critical   | Fixed  | Ledger; CloudKit                         |
|      12 | Critical   | Fixed  | Sync; CloudKit; Phase 2                  |
|      13 | Data Model | Fixed  | Data model DDL                           |
|      14 | Data Model | Fixed  | Product spec §6; Recurring               |
|      15 | Data Model | Fixed  | Data model idempotency; MCP              |
|      16 | Data Model | Fixed  | Data model idempotency; MCP              |
|      17 | Data Model | Fixed  | MCP feature/protocol                     |
|      18 | Data Model | Fixed  | Ledger; Income/Expenses                  |
|      19 | Data Model | Fixed  | Wallets; Ledger; Multi-currency          |
|      20 | Data Model | Fixed  | Data model lifecycle; Wallets            |
|      21 | Data Model | Fixed  | Ledger; Wallets                          |
|      22 | Data Model | Fixed  | Ledger; CloudKit                         |
|      23 | Data Model | Fixed  | Data model categories; Expenses          |
|      24 | Data Model | Fixed  | Data model; Onboarding                   |
|      25 | Data Model | Fixed  | Data model Asset; OCR; Backup            |
|      26 | Data Model | Fixed  | OCR; Data model lifecycle                |
|      27 | Data Model | Fixed  | Data model time types; Recurring         |
|      28 | Data Model | Fixed  | Dashboard; Recurring                     |
|      29 | Data Model | Fixed  | Data model indexes                       |
|      30 | Data Model | Fixed  | Data model ShareReference; Family        |
|      31 | Data Model | Fixed  | Data model lifecycle; Budget; Investment |
|      32 | Data Model | Fixed  | Product spec §7; Dashboard               |
|      33 | Data Model | Fixed  | Investment; Phase 1.5                    |
|      34 | Data Model | Fixed  | Multi-currency; Data model rates         |
|      35 | MCP        | Fixed  | MCP protocol; Phase 3                    |
|      36 | MCP        | Fixed  | MCP protocol; MCP feature                |
|      37 | MCP        | Fixed  | MCP protocol schemas                     |
|      38 | MCP        | Fixed  | MCP protocol; MCP feature                |
|      39 | MCP        | Fixed  | Product spec §9; Phase 3                 |
|      40 | MCP        | Fixed  | MCP protocol authorization               |
|      41 | MCP        | Fixed  | MCP protocol; Security                   |
|      42 | MCP        | Fixed  | MCP feature; Security; Phase 3           |
|      43 | MCP        | Fixed  | MCP protocol reads                       |
|      44 | MCP        | Fixed  | MCP protocol pagination                  |
|      45 | MCP        | Fixed  | MCP protocol resources                   |
|      46 | MCP        | Fixed  | MCP protocol startup; Security           |
|      47 | MCP        | Fixed  | MCP protocol tests                       |
|      48 | MCP        | Fixed  | MCP compatibility; Architecture          |
|      49 | MCP        | Fixed  | MCP read limits                          |
|      50 | Sync       | Fixed  | Product spec §8; CloudKit                |
|      51 | Sync       | Fixed  | Sync; CloudKit                           |
|      52 | Sync       | Fixed  | CloudKit tombstones/recovery             |
|      53 | Sync       | Fixed  | Sync scope; CloudKit                     |
|      54 | Sync       | Fixed  | CloudKit schema deployment               |
|      55 | Sync       | Fixed  | Security; CloudKit                       |
|      56 | Sync       | Fixed  | CloudKit recovery; Sync UX               |
|      57 | Sync       | Fixed  | MCP reads; Sync UX                       |
|      58 | Sync       | Fixed  | Family; Phase 3                          |
|      59 | Sync       | Fixed  | Family permissions; Security             |
|      60 | Sync       | Fixed  | Family operations; CloudKit              |
|      61 | Feature    | Fixed  | OCR; Phase 1.5                           |
|      62 | Feature    | Fixed  | Recurring scheduling; CloudKit           |
|      63 | Feature    | Fixed  | Recurring scheduling/update              |
|      64 | Feature    | Fixed  | Recurring IDs; Data model index          |
|      65 | Feature    | Fixed  | Budget; Data model                       |
|      66 | Feature    | Fixed  | Budget; Security; Onboarding             |
|      67 | Feature    | Fixed  | Backup archive contents                  |
|      68 | Feature    | Fixed  | Backup restore/import modes              |
|      69 | Feature    | Fixed  | Backup integrity                         |
|      70 | Feature    | Fixed  | Backup encryption                        |
|      71 | Feature    | Fixed  | Backup storage/recovery                  |
|      72 | Feature    | Fixed  | Backup CSV; Sync                         |
|      73 | Security   | Fixed  | Product spec §10; Security               |
|      74 | Security   | Fixed  | Security storage; OCR; Backup            |
|      75 | Security   | Fixed  | Security secrets                         |
|      76 | Security   | Fixed  | Security threat model                    |
|      77 | Security   | Fixed  | Product/phase scope; Security            |
|      78 | Security   | Fixed  | Architecture packaging; Phase 3          |
|      79 | Security   | Fixed  | Architecture runtime strategy; OCR       |
|      80 | Security   | Fixed  | Product spec §§11–12; phase docs         |
|      81 | Security   | Fixed  | Product spec §§11, 13; system tests      |
|      82 | Security   | Fixed  | Product spec §§12–13; data/MCP policy    |
|      83 | Security   | Fixed  | Security diagnostics; CloudKit; Backup   |
|      84 | Security   | Fixed  | Product spec §§2, 4; all phase docs      |
