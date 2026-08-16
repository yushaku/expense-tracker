# Feature: MCP Server

> MCP tools, Resources, Structured errors

---

## Overview

The MCP (Model Context Protocol) Server allows AI agents (Claude Code, Codex, etc.) to interact with the user's expense data in a structured, safe way.

## Transport

**stdio** — runs locally on the user's Mac. AI agents launch it as a subprocess.

## Configuration

```json
{
  "mcpServers": {
    "expense-tracker": {
      "command": "node",
      "args": ["/Users/nami/work/expense-tracker/apps/mcp-server/dist/index.js"],
      "env": {
        "EXPENSE_DB_PATH": "~/Library/Application Support/expense-tracker/expenses.db",
        "EXPENSE_MCP_READONLY": "false"
      }
    }
  }
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EXPENSE_DB_PATH` | Path to SQLite DB | `~/Library/Application Support/expense-tracker/expenses.db` |
| `EXPENSE_MCP_READONLY` | If `true`, reject all writes | `false` |

## Tools (9 Phase 1)

### Write Tools

| Tool | Description | Params |
|------|-------------|--------|
| `add_expense` | Add expense | amount, currency, category, description?, date?, walletId, merchant?, dryRun?, clientRequestId |
| `update_expense` | Update expense | id, amount?, category?, description?, date? |
| `void_expense` | Soft void expense | id |
| `add_income` | Add income | amount, currency, source?, description?, date?, walletId, type?, dryRun?, clientRequestId |
| `update_income` | Update income | id, amount?, source?, description?, date? |
| `void_income` | Soft void income | id |
| `transfer` | Transfer between wallets | fromWalletId, toWalletId, amount, date?, note?, dryRun?, clientRequestId |

### Read Tools

| Tool | Description | Params |
|------|-------------|--------|
| `get_wallets` | List wallets with balance | — |
| `search_transactions` | Search expense+income | from?, to?, walletId?, category?, type?, text?, includeVoided?, limit?, offset? |

## Resources

Resources provide static/semi-static data to agents without tool calls.

| Resource | URI | Description |
|----------|-----|-------------|
| Categories | `expense://categories` | List of expense categories with labels |
| Wallets | `expense://wallets` | Current wallets with balance |

## Dry-Run Mode

Write tools accept `dryRun: true`. When true:
- Validate input
- Return preview of what would happen
- Do NOT write to DB
- Do NOT consume idempotency key

Example response:
```json
{
  "dryRun": true,
  "wouldCreate": {
    "id": "preview-xxx",
    "amount": 50000,
    "category": "food",
    "walletId": "wallet-1"
  },
  "newWalletBalance": 450000
}
```

## Idempotency

- `clientRequestId` included in write requests
- Same key + same payload → return original record (no duplicate)
- Same key + different payload → error `IDEMPOTENCY_CONFLICT`
- Dry-run does NOT consume key

## Structured Errors

All errors returned as:
```json
{
  "error": "ERROR_CODE",
  "message": "Human readable message",
  "field": "amount"  // optional, for validation errors
}
```

### Error Codes

| Code | HTTP Equivalent | Description |
|------|-----------------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid input |
| `NOT_FOUND` | 404 | Record not found |
| `ALREADY_VOIDED` | 409 | Record already voided |
| `IDEMPOTENCY_CONFLICT` | 409 | Duplicate clientRequestId |
| `INSUFFICIENT_AVAILABLE_CREDIT` | 400 | Over credit limit |
| `TRANSFER_SAME_WALLET` | 400 | from == to |
| `CURRENCY_UNSUPPORTED` | 400 | Non-VND currency |
| `DB_UNAVAILABLE` | 500 | Cannot access database |

## Read-Only Mode

Set `EXPENSE_MCP_READONLY=true` to reject all writes. Agent can query but not mutate.

Use case: Share read access with an agent for analysis only.

## Agent Behavior Patterns

### Reacting to queries
- "How much did I spend this week?" → `search_transactions` + compute sum
- "Add 50k for lunch" → `add_expense` with defaults

### Clarification
- "Add 500k" (no category) → error VALIDATION_ERROR, ask which category
- "Transfer 1M" (no from/to) → error, ask which wallets

### Proactive recommendations (Phase 1.5+)
- "You're at 80% of food budget" → from budget tracking
- "Spending is up 30% vs last month" → from statistics

## Implementation

- Language: TypeScript
- MCP SDK: `@modelcontextprotocol/sdk`
- DB: `better-sqlite3` (sync, fast)
- Run: `tsx watch src/index.ts` (dev), `node dist/index.js` (prod)
