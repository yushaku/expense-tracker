# Phase 3 — Electron, MCP, and Family

## Goal

Add a hardened Mac Electron experience, an optional local AI advisor through MCP, and Apple-native family sharing.

## In scope

- Electron shell with sandboxed renderer, typed preload IPC, shared domain, and synced local projection.
- Local stdio MCP server with schemas, structured outputs, bounded cursor reads, read-only default, and audited opt-in writes.
- Add/update/void/transfer and feature write tools with required `clientRequestId`, `walletId` where scoped, and `dryRun`.
- CKShare invitation, participant permission, shared-zone sync, revoke/leave/recovery flows.

## Out of scope

Custom account/family backend, remotely hosted MCP, browser-exposed database, autonomous unconfirmed writes, and direct access by Electron renderer or MCP to raw tables.

## Acceptance criteria

- Electron security checklist and code-signing/notarization gates pass.
- MCP tool errors use `isError: true` results; every response validates against `outputSchema` and includes `structuredContent`.
- Default configuration cannot mutate; enabled writes are dry-runnable, durable-idempotent, atomic, and audited.
- Query size/count/time limits and opaque cursor pagination are enforced.
- CKShare owner/member/revoke/offline conflict tests preserve permissions and ledger convergence.

## Definition of done

Protocol/security/IPC/share/convergence/migration/backup tests pass; audit review proves every MCP mutation attempt is attributable without logging sensitive payloads.
