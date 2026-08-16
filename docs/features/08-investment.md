# Feature: Investment (Phase 1.5)

> Investment tracking: Gold, Crypto, ETF, Real Estate, Fund, Stock

---

## Overview

Track investment assets and their current value. Compute net worth and asset allocation.

## Investment Entity

```
Investment
├── id: uuid
├── name: string (Vàng SJC, Căn hộ Q7, BTC, VTI, ...)
├── type: enum [gold, real_estate, fund, crypto, etf, bond, stock, other]
├── currentValue: number
├── costBasis: number
├── quantity: number
├── unit: string (lượng, BTC, cổ phần, ...)
├── purchaseDate: ISO datetime
├── currency: string (VND)
├── notes: string
├── createdAt, updatedAt: ISO datetime
```

## Operations

### Create Investment
- Input: name, type, currentValue, costBasis, quantity, unit, purchaseDate, notes?
- Validation: all positive numbers, valid type

### Update Investment
- Input: id, currentValue?, name?, notes?
- Typically update currentValue as market changes
- costBasis and purchaseDate should NOT change

### Delete Investment
- Hard delete (no soft void for investments)

### Get Investments
- List all investments
- Include computed: profit/loss, profit %

## Computed Metrics

```
profit = currentValue - costBasis
profit % = (profit / costBasis) × 100
```

## Asset Allocation (Phase 1.5)

```
totalInvestmentValue = Σ(investment.currentValue)
allocation % per type = (Σ(type investments) / totalInvestmentValue) × 100
```

## Net Worth (Phase 1.5)

```
netWorth = Σ(wallet balance) + Σ(investment currentValue)
```

## UI Screens

- `/investments` — list with total value + profit/loss
- `/investments/[id]` — detail/edit
- `/investments/new` — create form
- Dashboard widget: "Tổng tài sản ròng"

## MCP Tools

| Tool | Description |
|------|-------------|
| `add_investment` | Create investment |
| `get_investments` | List investments |
| `update_investment_value` | Update currentValue |

## Edge Cases

- Investment with costBasis = 0 → profit% undefined, show N/A
- Update currentValue to 0 → show as closed/liquidated
- Multiple same-type investments → show subtotal
- Real estate with partial ownership → notes field
