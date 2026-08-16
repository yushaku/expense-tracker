# System: MCP Protocol

> MCP protocol implementation details

---

## Overview

The MCP (Model Context Protocol) server implements the protocol specification from `@modelcontextprotocol/sdk`.

## Protocol

### Transport

**stdio** — server runs as subprocess, communicates via stdin/stdout.

```
AI Agent (parent process)
    ↓ stdin (JSON-RPC 2.0)
MCP Server (child process)
    ↑ stdout (JSON-RPC 2.0)
```

### Message Format

All messages are JSON-RPC 2.0:

```json
// Request
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "add_expense",
    "arguments": { "amount": 50000, "category": "food" }
  }
}

// Response
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      { "type": "text", "text": "{\"success\": true}" }
    ]
  }
}

// Error
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "VALIDATION_ERROR",
    "data": { "field": "amount" }
  }
}
```

## Server Lifecycle

```
1. Initialize
   ← client sends initialize request
   → server responds with capabilities
   
2. List Tools
   ← client sends tools/list
   → server returns tool definitions
   
3. Call Tool
   ← client sends tools/call
   → server executes tool
   → server returns result
   
4. (Repeat step 3)
   
5. Shutdown
   ← client disconnects
   → server exits
```

## Capabilities

```json
{
  "capabilities": {
    "tools": {},
    "resources": {}
  }
}
```

## Tool Schema

Tools follow JSON Schema for input validation:

```json
{
  "name": "add_expense",
  "description": "Thêm một khoản chi tiêu mới",
  "inputSchema": {
    "type": "object",
    "properties": {
      "amount": { "type": "number", "description": "Số tiền" },
      "currency": { "type": "string", "default": "VND" },
      "category": {
        "type": "string",
        "enum": ["food", "transport", "shopping", "entertainment", "healthcare", "education", "bills", "other"]
      },
      "description": { "type: "string" },
      "date": { "type": "string", "format": "date-time" },
      "walletId": { "type": "string" },
      "merchant": { "type": "string" },
      "dryRun": { "type": "boolean", "default": false },
      "clientRequestId": { "type": "string" }
    },
    "required": ["amount", "category"]
  }
}
```

## Resources

Resources provide read-only data:

```json
{
  "uri": "expense://categories",
  "name": "Expense Categories",
  "description": "Danh sách danh mục chi tiêu",
  "mimeType": "application/json"
}
```

Resource content returned as:

```json
{
  "uri": "expense://categories",
  "mimeType": "application/json",
  "text": "[{\"id\":\"food\",\"label\":\"Ăn uống\"}, ...]"
}
```

## Error Handling

### Structured Errors

```typescript
class ExpenseError extends Error {
  constructor(
    public code: string,
    message: string,
    public field?: string
  ) {
    super(message);
  }
}

const ERROR_CODES = {
  VALIDATION_ERROR: { code: -32602, status: 400 },
  NOT_FOUND: { code: -32602, status: 404 },
  ALREADY_VOIDED: { code: -32602, status: 409 },
  IDEMPOTENCY_CONFLICT: { code: -32602, status: 409 },
  INSUFFICIENT_AVAILABLE_CREDIT: { code: -32602, status: 400 },
  TRANSFER_SAME_WALLET: { code: -32602, status: 400 },
  CURRENCY_UNSUPPORTED: { code: -32602, status: 400 },
  DB_UNAVAILABLE: { code: -32603, status: 500 },
};
```

### Agent Recovery

When agent receives error:
1. Parse error code
2. If VALIDATION → prompt user for correction
3. If NOT_FOUND → search for similar records
4. If IDEMPOTENCY → return cached result
5. If DB_UNAVAILABLE → retry once, then alert user

## Idempotency

### Key Strategy

- `clientRequestId` provided by agent
- Server stores key with response
- Same key + same payload → return original
- Same key + different payload → error

### Key Expiry

- Keys kept for 24 hours
- After expiry, same key can be reused
- Prevents unbounded growth

## Read-Only Mode

Environment variable `EXPENSE_MCP_READONLY=true`:
- `tools/list` returns tools but marks them as read-only
- `tools/call` for writes returns error
- Read tools work normally

## Dry-Run Mode

Write tools accept `dryRun: true`:
- Validate input
- Return preview
- Do NOT write to DB
- Do NOT consume idempotency key

## Security Considerations

- Server runs locally, no network exposure
- No authentication (trust local process)
- Read-only mode for analysis
- Agent can mutate data — user trusts agent
- Future: audit log for agent actions

## Testing

```bash
# Manual test
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.json

# Integration test
npm run test:mcp
```
