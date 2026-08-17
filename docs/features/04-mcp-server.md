# Feature: MCP Server (Phase 3)

The optional Mac-local MCP server lets an AI advisor inspect finances and, only after explicit configuration, propose or perform bounded writes. It does not exist in earlier phases.

## Safety contract

- stdio only; no network listener.
- `EXPENSE_MCP_READONLY=true` by default. Writes return a structured `READ_ONLY` tool result unless explicitly enabled.
- Every tool defines valid `inputSchema` and `outputSchema`, returns `structuredContent` plus Vietnamese text, and uses `isError: true` for domain/tool errors.
- Wallet-scoped operations require `walletId`.
- Every add/update/void/transfer/budget/investment/recurring write requires `clientRequestId` and supports `dryRun`.
- Dry-run validates/previews but creates no row, operation, audit commit, sync item, or idempotency record.
- Committed and denied/failed write attempts create redacted audit records.

## Reads

Search and summaries enforce a 200-character query, maximum page size 100 (default 50), bounded date range, stable opaque cursor pagination, and 5-second normal timeout. Output is minimized to requested fields and redacts receipt paths/content.

## Writes

Tools call `packages/domain`; no tool writes raw SQLite. Same `(operation, clientRequestId)` and payload returns the prior result permanently for financial writes; payload mismatch is `IDEMPOTENCY_CONFLICT`. Update/void are explicit operations and preserve financial history.

## Acceptance

Protocol contract tests cover every schema/result, read-only default, enablement, dry-run non-mutation, replay across restart, audit rows, wallet scope, limits, cursors, timeout cancellation, stdout purity, and sensitive-data redaction. Detailed wire examples are in `docs/system/04-mcp-protocol.md`.
