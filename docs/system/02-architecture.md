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
│  │  Expo React Native  │       │  Electron + Tamagui          │  │
│  │  + Tamagui UI       │       │  (shared components)         │  │
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

### Presentation Layer (Tamagui)

- **Expo Router** — file-based routing
- **Tamagui** — cross-platform UI kit (shared components for mobile + desktop)
- **Zustand** — state management

### Shared UI Package

```
packages/ui/
├── src/
│   ├── components/        # Shared components (Button, Card, Input, etc.)
│   ├── theme/             # Tamagui config (colors, spacing, typography)
│   └── tokens/            # Design tokens (raw values)
├── tamagui.config.ts      # Tamagui configuration
└── package.json
```

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
├── mobile/                # Presentation + Domain + Data (mobile)
│   ├── app/               # Expo Router pages
│   ├── components/        # Mobile-specific components
│   ├── hooks/             # React hooks
│   ├── services/          # Domain services
│   └── stores/            # Zustand stores
├── desktop/               # Electron wrapper (shares packages/ui)
│   ├── electron/          # Electron main process
│   └── renderer/          # Tamagui renderer (shared + desktop-specific)
├── mcp-server/            # MCP Server (infrastructure)
│   └── src/
│       ├── index.ts       # Entry point
│       ├── tools/         # Tool implementations
│       ├── db.ts          # Database access
│       └── ledger.ts      # Ledger logic
packages/
├── ui/                    # Shared Tamagui components + theme
│   ├── src/components/    # Button, Card, Input, Chip, FAB, List, Dialog
│   ├── src/theme/         # Tamagui theme tokens
│   └── tamagui.config.ts  # Tamagui config
└── shared/                # Shared types + utils
    └── src/
        ├── types.ts       # All type definitions
        └── utils.ts       # Utility functions
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
