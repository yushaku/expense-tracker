# Feature: Budgets (Phase 1.5)

A budget limits active expense spending for a category and optional wallet over a weekly, monthly, or yearly local-calendar period.

Required fields: ID, scope, `limitMinor > 0`, currency, period, local anchor/timezone, status, and common timestamps. Enforce FK integrity and one active budget per `(scope, period, anchor)`; archive/void instead of deleting referenced history.

```text
spentMinor = Σ matching active expenses in period
remainingMinor = limitMinor - spentMinor
utilizationBasisPoints = floor(spentMinor * 10_000 / limitMinor)
```

Transfers, income, voided expenses, and credit-card payments are excluded. Integer math is used throughout. Phase 2 reporting converts only with explicit rate snapshots and labels partial data when a rate is missing.

Vietnamese UI shows progress, remaining/over-budget state, period boundary, and optional threshold alerts. Notifications are advisory and recomputed from ledger data.

Acceptance: timezone/month/week edges, updates/voids, late recurring entries, card expenses, currency mismatch, overflow, and exact reconciliation tests pass. Phase 3 MCP writes require `walletId` when scoped, `clientRequestId`, dry-run, enabled writes, and audit.
