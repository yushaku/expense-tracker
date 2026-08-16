# Feature: Multi-Currency (Phase 2)

> Support VND, USD, EUR, etc. with exchange rates

---

## Overview

Phase 1 is VND-only. Phase 2 adds multi-currency support with exchange rate conversion.

## Currency Entity

```
Currency
├── code: string (USD, EUR, GBP, JPY, ...)
├── symbol: string ($, €, ...)
├── name: string
```

## Exchange Rate

```
ExchangeRate
├── from: string (currency code)
├── to: string (currency code)
├── rate: number
├── source: string (ECB, manually, ...)
├── updatedAt: ISO datetime
```

## Operations

### Add Transaction in Foreign Currency
- Select currency from list
- Amount entered in foreign currency
- Auto-convert to VND for reporting (optional)

### Exchange Rate Update
- Manual entry
- Or API fetch (ECB, vcbexchangerates, etc.)
- Cache with TTL (24h)

### Currency Conversion

```
convertedAmount = amount × exchangeRate
```

## Display

- Primary currency: VND (configurable)
- Foreign amount shown in parentheses
- Example: "$500 (~12,500,000 VND)"

## UI Changes

- Wallet: add `currency` selector
- Expense/Income: add `currency` selector
- Settings: add `primaryCurrency`, `exchangeRateSource`
- Dashboard: toggle between original and converted values

## Edge Cases

- Exchange rate unavailable → prompt manual entry
- Rate expired → show warning
- Historical transactions → use rate at transaction time
- CCY change → recalculate all metrics
