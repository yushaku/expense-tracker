# Feature: Dashboard

## Metrics

All metrics derive from active ledger/source records and integer arithmetic for a selected local-calendar period.

```text
nonCreditAssets = Σ active non-credit wallet balances
creditCardDebt = Σ(card expenses - card payments)
investmentValue = Σ latest active investment currentValueMinor
netWorth = nonCreditAssets + investmentValue - creditCardDebt
cashFlow = income - expenses
savingsRate = income == 0 ? null : (income - expenses) / income
```

Transfers are excluded from income/expense/cash-flow totals. Credit limits and available credit are excluded from assets and net worth. Voided and sample data follow the user’s explicit sample visibility selection.

Phase 1 supports one currency (VND). Phase 2 converts each metric with immutable rate snapshots to the selected reporting currency and labels rate time/source; missing rates produce partial-data UI, never an assumed 1:1 conversion.

## UI

Vietnamese cards show “Tài sản”, “Dư nợ thẻ”, “Giá trị đầu tư”, “Tài sản ròng”, “Thu”, and “Chi”. Negative net worth/cash flow is visually and textually explicit. Category charts use source categories and reconcile to the displayed expense total.

## Acceptance

- Dashboard totals equal independent ledger reconciliation for every filter.
- Card purchase/payment and transfer do not inflate assets or cash flow.
- Empty income yields “Chưa có dữ liệu” savings rate, not infinity/NaN.
- Month boundaries use the user timezone and UTC instants; pagination cannot change aggregate totals.
