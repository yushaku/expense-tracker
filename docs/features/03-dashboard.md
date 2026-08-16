# Feature: Dashboard

> Cash flow, Category breakdown, Savings rate, Wallet balances

---

## Overview

Dashboard shows a quick snapshot of the user's financial status. All metrics derived from ledger (active transactions only).

## Metrics

### Cash Flow (Phase 1)

```
Cash flow = Σ(income active) − Σ(expense active)
```

- Period: current month (or custom range)
- Exclude: transfer, voided, opening_balance
- Display: positive (surplus) / negative (deficit)

### Category Breakdown (Phase 1)

```
Category % = (Σ(expense active in category) / Σ(all expense active)) × 100
```

- Display: pie chart or bar chart
- Period: current month
- Categories with 0% can be hidden

### Savings Rate (Phase 1)

```
Savings rate = (Cash flow / Σ(income active)) × 100
```

- If income = 0 → display 0%
- Period: current month

### Wallet Balances (Phase 1)

- Show all wallets with derived balance
- CC wallet shows available credit (not balance)

### Net Worth (Phase 1.5)

```
Net Worth = Σ(Wallet balance) + Σ(Investment currentValue)
```

### Asset Allocation (Phase 1.5)

```
Allocation % = (Asset value / Net Worth) × 100
```

## Period Selection

- Default: current month
- Options: this week, this month, last month, custom range
- All metrics recalculate based on selected period

## Monthly Report (Basic Phase 1)

- Total income, total expense, cash flow
- Top 3 categories by spending
- Savings rate
- Compare to last month (% change)

## UI Screens

- `/` — dashboard home
  - Period selector (week/month/custom)
  - Cash flow card
  - Category breakdown chart
  - Savings rate card
  - Wallet balances list
- `/stats` — detailed statistics (Phase 1.5)

## Edge Cases

- No transactions in period → show 0 / empty state
- No income → savings rate = 0%
- All categories 0 → hide breakdown
- Voided transactions excluded from all metrics
