# System: Architecture

> High-level system architecture

---

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          User Devices                            │
│                                                                   │
│  ┌────────────────────┐       ┌──────────────────────────────┐  │
│  │      iPhone         │       │           Mac                 │  │
│  │                     │       │                              │  │
│  │  Expo React Native  │       │  Expo Web / Electron         │  │
│  │                     │       │                              │  │
│  │  ┌──────────────┐  │       │  ┌────────────────────────┐  │  │
│  │  │ Zustand Store│  │       │  │   MCP Server            │  │  │
│  │  └──────┬───────┘  │       │  │   (Node.js/TS)          │  │  │
│  │         │          │       │  │                         │  │  │
│  │  ┌──────▼───────┐  │       │  │   better-sqlite3        │  │  │
│  │  │ expo-file-  │  │       │  │                         │  │  │
│  │  │ system      │  │       │  └───────────┬─────────────┘  │  │
│  │  └──────┬───────┘  │       │              │                 │  │
│  │         │          │ Export/│              │                 │  │
│  │  ┌──────▼───────┐  │ Import │  ┌───────────▼─────────────┐  │  │
│  │  │ SQLite DB    │──┼────────┼──► SQLite DB               │  │  │
│  │  └──────────────┘  │ (1.5+) │  └─────────────────────────┘  │  │
│  └────────────────────┘       └──────────────────────────────┘  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Layers

### Presentation Layer (React Native)

- **Expo Router** — file-based routing
- **React Native Paper** — Material Design UI components
- **Zustand** — state management

### Domain Layer

- **LedgerEngine** — balance derivation, invariant enforcement
- **TransactionService** — CRUD operations
- **SyncService** — export/import, future CloudKit

### Data Layer

- **SQLite** — local database
- **expo-file-system** — file operations on mobile
- **better-sqlite3** — SQLite driver for MCP server

### Infrastructure Layer

- **MCP Server** — AI agent interface
- **Notifications** — daily reminders
- **OCR** — receipt scanning

## Module Boundaries

```
apps/
├── mobile/              # Presentation + Domain + Data (mobile)
│   ├── app/             # Expo Router pages
│   ├── components/      # UI components
│   ├── hooks/           # React hooks
│   ├── services/        # Domain services
│   └── stores/          # Zustand stores
├── mcp-server/          # MCP Server (infrastructure)
│   └── src/
│       ├── index.ts     # Entry point
│       ├── tools/       # Tool implementations
│       ├── db.ts        # Database access
│       └── ledger.ts    # Ledger logic
packages/
└── shared/              # Shared types + utils
    └── src/
        ├── types.ts     # All type definitions
        └── utils.ts     # Utility functions
```

## Data Flow

### Read (Dashboard)
```
UI → Zustand Store → SQLite Query → UI Render
```

### Write (Add Expense)
```
UI Form → Validate → LedgerEngine.createExpense() → SQLite Insert → Update Store → UI Refresh
```

### MCP Write
```
AI Agent → MCP Server → Validate → LedgerEngine.createExpense() → SQLite Insert → Response
```

### Transfer
```
UI Form → Validate → LedgerEngine.createTransfer() → SQLite Insert (2 entries) → Update Store → UI Refresh
```

## Sync Strategy

| Phase | Strategy | Implementation |
|-------|----------|----------------|
| 1 | No sync | Single device, local SQLite |
| 1.5 | Export/Import | JSON/CSV file transfer |
| 2 | CloudKit | Apple private database, auto-sync |

## Security

- **Phase 1:** Local only, no auth (Face ID for app lock)
- **Phase 2:** iCloud account for sync
- **Phase 3:** Email/password or OAuth for family sharing

## Scaling Considerations

- Single user: SQLite handles millions of records
- No server needed (Phase 1-2)
- MCP server runs locally
- Future: CloudKit handles multi-device sync
