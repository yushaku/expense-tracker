# System: CloudKit Sync (Phase 2)

> CloudKit sync design

---

## Overview

Phase 2 introduces true multi-device sync via CloudKit (Apple private database).

## Why CloudKit

| Criteria | CloudKit | Supabase |
|----------|----------|----------|
| Privacy | ✅ End-to-end encrypted | ⚠️ Server can read |
| Apple integration | ✅ Native | ⚠️ SDK required |
| Cost | ✅ Free tier generous | ⚠️ Paid at scale |
| Cross-platform | ❌ Apple only | ✅ Any platform |
| MCP access | ⚠️ Indirect | ✅ Direct |

**Decision:** CloudKit (Apple-only, privacy-first).

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   CloudKit                        │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │         Private Database                     │ │
│  │                                               │ │
│  │  Record Types:                                │ │
│  │  • Expense                                    │ │
│  │  • Income                                     │ │
│  │  • Wallet                                     │ │
│  │  • Transfer                                   │ │
│  │  • Budget                                     │ │
│  │  • Investment                                 │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
└──────────────────────┬──────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌──────────┐
   │ iPhone   │   │  Mac    │   │  MCP     │
   │ App      │   │  App    │   │  Server  │
   └─────────┘   └─────────┘   └──────────┘
```

## Sync Strategy

### Record Types

Each entity maps to a CloudKit record type:

| Entity | Record Type | Fields |
|--------|-------------|--------|
| Wallet | `Wallet` | id, name, type, currency, creditLimit |
| Expense | `Expense` | id, amount, currency, category, description, date, walletId, status, clientRequestId |
| Income | `Income` | id, amount, currency, source, description, date, walletId, type, status, clientRequestId |
| Transfer | `Transfer` | id, fromWalletId, toWalletId, amount, currency, date, status |

### Conflict Resolution

**Last-writer-wins with vector clock:**

1. Each record has `modifiedAt` timestamp
2. On sync, compare `modifiedAt`
3. Newer timestamp wins
4. If equal, device ID breaks tie

### Sync Flow

```
1. Local change → save to SQLite (immediately)
2. Mark record as `syncStatus: 'pending'`
3. Background sync → push to CloudKit
4. On success → mark `syncStatus: 'synced'`
5. On failure → mark `syncStatus: 'error'`, retry later
```

### Pull Flow

```
1. Fetch changes from CloudKit (using change token)
2. Apply to local SQLite
3. If conflict → last-writer-wins
4. Update UI
```

## MCP Integration

MCP server reads from local SQLite. Sync happens at app layer:

```
iPhone App ← CloudKit → Mac App → SQLite → MCP Server
```

MCP always reads from local DB. If Mac app hasn't synced, MCP sees stale data.

### Alternative: MCP Reads from CloudKit Directly

```
MCP Server → CloudKit SDK → CloudKit
```

**Tradeoff:**
- ✅ Always fresh data
- ❌ Adds complexity (MCP needs CloudKit auth)
- ❌ MCP on non-Apple platforms blocked

**Decision:** MCP reads local SQLite. Mac app handles sync.

## Schema Migration

When CloudKit schema changes:
1. Add fields to local SQLite
2. Push to CloudKit (auto-creates fields)
3. Older app versions ignore new fields

## Offline Support

- Full functionality offline
- Queue changes while offline
- Auto-sync when back online
- Conflict resolution on reconnect

## Testing

- Mock CloudKit for unit tests
- Integration tests with CloudKit sandbox
- Conflict simulation
- Offline queue tests
