# System: MCP Protocol (Phase 3)

MCP is absent from Phases 1, 1.5, and 2. In Phase 3 a local Node.js/TypeScript server runs over stdio on Mac and calls `packages/domain`; it never opens a network port or bypasses repositories.

## Defaults and limits

| Setting | Default | Maximum |
|---|---:|---:|
| `EXPENSE_MCP_READONLY` | `true` | writes require explicit `false` |
| query text | — | 200 characters |
| page size | 50 | 100 rows |
| tool execution | 5 s | 10 s for export-like reads |
| note/merchant input | — | 1,000 / 120 characters |
| date range | 31 days | 366 days |

Reads use opaque, signed/versioned cursors based on stable `(occurredAtUtc, id)` ordering. Responses include `items`, `nextCursor`, and `hasMore`; offset pagination is forbidden. SQLite progress handlers/abort signals cancel timed-out work.

## Tool catalog

Read tools: `list_wallets`, `get_wallet_summary`, `search_transactions`, `get_spending_summary`, `list_budgets`, `list_recurring`, `list_investments`.

Write tools: `add_expense`, `update_expense`, `void_expense`, `add_income`, `update_income`, `void_income`, `transfer`, `void_transfer`, and corresponding budget/investment/recurring create/update/void tools.

All wallet-scoped tools require `walletId`. Every write requires `clientRequestId` and accepts `dryRun` (default `false`). Update/void operations are first-class idempotent commands; wallet/currency changes require void-and-recreate. Dry-run validates and previews without mutation, audit commit, sync operation, or idempotency consumption.

## Valid schema example

Money crosses JSON as a decimal-string count of minor units so precision does not depend on JavaScript.

```json
{
  "name": "add_expense",
  "description": "Thêm khoản chi",
  "inputSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "walletId": { "type": "string", "minLength": 1 },
      "amountMinor": { "type": "string", "pattern": "^[1-9][0-9]*$" },
      "currency": { "type": "string", "pattern": "^[A-Z]{3}$" },
      "categoryId": { "type": "string", "minLength": 1 },
      "occurredAtUtc": { "type": "string", "format": "date-time" },
      "occurredOffsetMinutes": { "type": "integer", "minimum": -840, "maximum": 840 },
      "note": { "type": "string", "maxLength": 1000 },
      "clientRequestId": { "type": "string", "minLength": 8, "maxLength": 128 },
      "dryRun": { "type": "boolean", "default": false }
    },
    "required": ["walletId", "amountMinor", "currency", "categoryId", "occurredAtUtc", "occurredOffsetMinutes", "clientRequestId"]
  },
  "outputSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "ok": { "type": "boolean" },
      "dryRun": { "type": "boolean" },
      "expenseId": { "type": "string" },
      "error": {
        "type": "object",
        "properties": { "code": { "type": "string" }, "message": { "type": "string" }, "field": { "type": "string" } },
        "required": ["code", "message"]
      }
    },
    "required": ["ok", "dryRun"]
  }
}
```

## Results and errors

Tool success returns both machine-readable `structuredContent` and a text mirror:

```json
{
  "structuredContent": { "ok": true, "dryRun": false, "expenseId": "..." },
  "content": [{ "type": "text", "text": "Đã thêm khoản chi." }],
  "isError": false
}
```

Domain/tool failures are not JSON-RPC errors:

```json
{
  "structuredContent": { "ok": false, "dryRun": false, "error": { "code": "VALIDATION_ERROR", "message": "Số tiền không hợp lệ", "field": "amountMinor" } },
  "content": [{ "type": "text", "text": "Không thể thêm khoản chi: số tiền không hợp lệ." }],
  "isError": true
}
```

JSON-RPC errors are reserved for malformed protocol messages, unknown methods, and server-level protocol failure. Codes exposed to tools include `VALIDATION_ERROR`, `NOT_FOUND`, `READ_ONLY`, `IDEMPOTENCY_CONFLICT`, `ALREADY_VOIDED`, `LIMIT_EXCEEDED`, `TIMEOUT`, and `DB_UNAVAILABLE`.

## Write safety and audit

Committed writes perform authorization/read-only check, schema validation, domain validation, durable idempotency lookup, domain write, immutable operation append, and audit append in one transaction. Audit includes actor, tool, target IDs, request ID, outcome, and timestamps, but redacts amounts, notes, and receipt/OCR content. Failed and denied write attempts are also audited without sensitive payloads.

## Tests

Contract tests enumerate all tools and validate schemas, required `walletId`, `dryRun`, `clientRequestId`, output-schema conformance, text/structured equivalence, `isError`, read-only default, no dry-run mutation, durable replay, audit records, cursor stability, limits, cancellation, and stdout purity.
