# Feature: Sync & Export/Import

> Export CSV/JSON → Import → CloudKit sync (Phase 2)

---

## Overview

Phase 1 has no sync. Data lives on single device. Users can export/import to move data.

## Phase 1: Export/Import

### Export CSV
- All expense+income+transfer records
- Columns: date, type, category/source, amount, currency, description, wallet, status
- Voided records: include with `[VOIDED]` marker
- Filename: `expenses_YYYY-MM-DD.csv`

### Export JSON (Backup)
- Full data dump including:
  - wallets
  - expenses
  - incomes
  - transfers
  - budgets (Phase 1.5)
  - investments (Phase 1.5)
- Format: JSON with metadata (`version`, `exportedAt`, `deviceId`)
- Filename: `expense_tracker_backup_YYYY-MM-DD.json`

### Import JSON
- Restore from backup
- Validation: schema check
- Warning: "Import sẽ ghi đè toàn bộ dữ liệu hiện tại"
- Confirm before apply

### Import CSV (Phase 1.5+)
- Parse CSV → create records
- Required columns: date, amount, category
- Validation errors → show summary

## Phase 2: CloudKit Sync

See `system/05-cloudkit.md` for details.

- Apple-only, privacy-focused
- Private database per user
- Conflict resolution: last-write-wins with vector clock
- MCP reads from synced DB

## UI Screens

- `/settings/export` — export options
- `/settings/import` — import file picker
- Sync status indicator (Phase 2)

## Edge Cases

- Import with no wallets → create from data
- Import with duplicate clientRequestId → skip
- Export with no data → empty file
- Import from different schema version → migration
- Large dataset export → stream to file
