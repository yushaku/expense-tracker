# System: Architecture

## Decision

The product is iPhone-first and expands without changing domain semantics.

| Phase | Runtime architecture                                                            |
| ----- | ------------------------------------------------------------------------------- |
| 1/1.5 | `apps/iphone` → `packages/domain` → SQLite repository                           |
| 2     | iPhone + `apps/mac-web` → domain → local projection + CloudKit operation sync   |
| 3     | Adds Electron and local MCP adapters over the same domain and synced projection |

There is no Mac process, shared filesystem database, Electron runtime, MCP server, or CloudKit dependency in Phase 1.

## Repository boundaries

```text
apps/
  iphone/          # Expo React Native; Phase 1+
  mac-web/         # Expo Web wrapper; Phase 2+
  mac-electron/    # Electron shell; Phase 3+
  mcp-server/      # local stdio adapter; Phase 3+
packages/
  domain/          # canonical entities, money, commands, ledger, schedules
  storage-sqlite/  # migrations and repositories
  sync-cloudkit/   # operation/asset sync; Phase 2+
  ui/              # platform-neutral components only
```

Dependencies point inward. `domain` imports no Expo, Electron, SQLite, CloudKit, or MCP module. Adapters translate transport/storage types but do not recalculate balances or schedules.

## Write path

```text
UI/MCP command → validate in domain → idempotency check → SQL transaction
  → append Operation → change projection rows → append LedgerEntry/AuditLog
  → store result → commit → publish UI event / enqueue sync
```

The repository transaction is the consistency boundary. Phase 2 uploads committed operations after local commit; it never makes CloudKit availability a prerequisite for a local write.

## Read path

Screens and MCP query local projections through repositories. Queries use stable `(occurredAtUtc, id)` cursor ordering, bounded filters, and do not read raw CloudKit records in presentation code.

## Platform decisions

- Expo React Native targets iPhone in Phase 1.
- Native Vision/VisionKit is exposed through an Expo module in Phase 1.5.
- Phase 2 Mac uses an Expo Web wrapper and CloudKit-capable bridge; no Node privileges.
- Phase 3 Electron owns its hardened preload/IPC boundary. Renderer code has no direct filesystem or Node access.
- MCP is a local stdio child process in Phase 3 and has no network listener.
- Apple CKShare supplies family access control; there is no custom identity/backend.

## Failure model

- SQLite write failure: roll back every projection, ledger, operation, and idempotency change.
- Sync failure: retain operation in outbox and retry with bounded exponential backoff.
- Asset failure: keep metadata pending; never claim receipt synchronization until checksum verifies.
- Projection corruption: rebuild from immutable operations after validating backup.
- MCP timeout: cancel/interrupt the query and return a structured tool error.

## Observability

Record event names, duration, row counts, schema version, and redacted error codes. Never log financial values, notes, OCR text, asset bytes/paths, tokens, or raw MCP arguments.

## Architecture acceptance

- A Phase 1 build contains no Mac, CloudKit, Electron, or MCP runtime dependency.
- All adapters pass the same `packages/domain` contract tests.
- Offline writes survive restart and later converge in Phase 2.
- No UI or transport layer writes ledger rows directly.
