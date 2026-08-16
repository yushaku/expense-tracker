# Feature: Budget (Phase 1.5)

> Budget CRUD + 80% alert

---

## Overview

Users can set spending limits per category or overall, and receive alerts when approaching limits.

## Budget Entity

```
Budget
├── id: uuid
├── category: enum [food, transport, shopping, entertainment, healthcare, education, bills, savings, other, all]
├── amount: number (positive)
├── currency: string (VND)
├── period: enum [weekly, monthly, yearly]
├── startDate: ISO datetime
├── endDate: ISO datetime | null (null = ongoing)
├── createdAt, updatedAt: ISO datetime
```

## Operations

### Create Budget
- Input: category, amount, period, startDate
- Validation: amount > 0, category valid, no duplicate (category+period)

### Update Budget
- Input: id, amount?, period?

### Delete Budget
- Soft delete or hard delete

### Get Budgets
- List all active budgets
- Include spent amount and % utilized

## Alert: 80% Threshold

- When spending reaches 80% of budget:
  - Push notification: "Bạn đã dùng 80% ngân sách ăn uống tháng này"
  - In-app badge
- When exceeded:
  - Push notification: "Bạn đã vượt ngân sách ăn uống"

## Utilization Calculation

```
spent = Σ(expense active in category, within period)
utilization = (spent / budget.amount) × 100
```

## UI Screens

- `/budgets` — list budgets with progress bars
- `/budgets/[id]` — detail/edit
- `/budgets/new` — create form

## MCP Tools

| Tool | Description |
|------|-------------|
| `set_budget` | Create/update budget |
| `get_budgets` | List budgets with utilization |

## Edge Cases

- Budget for "all" → tracks total spending across categories
- Period change → recalculate from start
- Voided expenses → excluded from spent amount
- Budget with no expenses → 0% utilized
- Category deleted → budget remains but shows "category not found"
