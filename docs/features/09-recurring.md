# Feature: Recurring Expenses (Phase 1.5)

> Recurring expenses: rent, subscription, etc.

---

## Overview

Automatically generate recurring expenses on a schedule. Reduces manual entry for predictable expenses.

## Recurring Entity

```
RecurringExpense
├── id: uuid
├── amount: number
├── currency: string (VND)
├── category: enum
├── description: string
├── walletId: string (FK → Wallet)
├── frequency: enum [daily, weekly, monthly, yearly]
├── startDate: ISO datetime
├── endDate: ISO datetime | null (null = ongoing)
├── lastGenerated: ISO datetime
├── nextDue: ISO datetime
├── isActive: boolean
├── createdAt, updatedAt: ISO datetime
```

## Operations

### Create Recurring
- Input: amount, category, description, walletId, frequency, startDate, endDate?
- Validation: amount > 0, startDate >= today (or past for backfill)

### Update Recurring
- Input: all fields except id
- Cannot change: createdAt

### Pause/Resume
- Toggle `isActive`

### Delete Recurring
- Hard delete (does NOT delete already-generated expenses)

## Generation Logic

- Cron job runs daily (or on app open)
- For each active recurring where `nextDue <= today`:
  - Create expense
  - Update `lastGenerated` = today
  - Compute `nextDue` based on frequency

### Frequency → Next Due

| Frequency | Next Due |
|-----------|----------|
| daily | today + 1 day |
| weekly | today + 7 days |
| monthly | today + 1 month |
| yearly | today + 1 year |

## UI Screens

- `/recurring` — list active/paused recurrings
- `/recurring/[id]` — detail/edit
- `/recurring/new` — create form
- Dashboard widget: "Hóa đơn sắp đến hạn"

## Edge Cases

- End date reached → auto-pause
- Skip one occurrence → manual pause + resume
- Wallet has insufficient balance → still create (overdraft)
- Delete wallet → cascade delete recurrings
- Duplicate creation prevention: check if expense already exists for that date
