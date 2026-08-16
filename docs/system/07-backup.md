# System: Backup

> Export/Import, backup/restore

---

## Overview

Data portability and disaster recovery.

## Export

### CSV Export

**Format:**
```csv
date,type,category,amount,currency,description,wallet,status
2024-01-15,expense,food,50000,VND,An truong,VI TIEN MAT,active
2024-01-15,income,salary,15000000,VND,Luong,TK NGAN HANG,active
2024-01-16,transfer,_,1000000,VND,Chuyen khoan,VI TIEN MAT,active
```

**Options:**
- Include voided: yes/no
- Include transfers: yes/no
- Date range: all/custom
- Encoding: UTF-8 (with BOM for Excel)

### JSON Export (Full Backup)

```json
{
  "version": "1.0.0",
  "exportedAt": "2024-01-15T10:30:00Z",
  "deviceId": "abc123",
  "data": {
    "wallets": [...],
    "expenses": [...],
    "incomes": [...],
    "transfers": [...],
    "budgets": [...],
    "investments": [...]
  },
  "metadata": {
    "totalRecords": 150,
    "checksum": "sha256:abc..."
  }
}
```

## Import

### JSON Import

1. Parse file
2. Validate schema
3. Preview changes
4. Confirm overwrite
5. Apply atomically

### Conflict Resolution

| Scenario | Resolution |
|----------|------------|
| Duplicate clientRequestId | Skip (keep existing) |
| Same ID different content | Prompt user |
| Missing wallet | Create from data |
| Unknown category | Map to "other" |

### CSV Import

1. Parse rows
2. Map columns to fields
3. Validate each row
4. Report errors (don't import)
5. Import valid rows

## Backup Strategies

### Manual Backup

- User taps "Export" in settings
- Save to Files app (iOS) or disk (macOS)
- Can upload to personal cloud storage

### Auto-Backup (Phase 1.5)

- Daily auto-export to app document directory
- Keep last 7 backups
- Cleanup older backups

### iCloud Backup (Phase 2)

- Part of iCloud sync
- Automatic, no user action needed

## Restore Flow

1. User selects backup file
2. App reads and validates schema
3. Shows preview: "Restore will replace all current data"
4. Confirm: "Backup current data first?"
5. Apply import
6. Recalculate balances
7. Show success/failure

## Disaster Recovery

### Data Loss Scenarios

| Scenario | Recovery |
|----------|----------|
| Lost iPhone | Restore from iCloud backup / Mac app |
| App deleted | Reinstall, restore from backup |
| Corrupted DB | Restore from latest backup |
| Accidental void | Export shows history, can recreate |

### Backup Reminders

- Weekly reminder: "Last backup: X days ago"
- Before major changes
- Before app update

## Testing

- Export/Import round-trip test
- Large dataset test
- Corrupted file handling
- Schema migration test
