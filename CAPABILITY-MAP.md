# Capability Map: MonMon

MonMon is a private, Apple-platform personal asset manager. Each module below is a small vertical feature that includes the minimum domain logic, storage, UI, and tests needed for the owner to try it on iPhone and Mac before the next module begins.

1. `cash-balance`
2. `savings-deposit`
3. `fund-etf-holdings`
4. `income-expense`
5. `account-transfer`
6. `debt-tracking`
7. `market-valuation`
8. `icloud-sync`
9. `recurring-transactions`
10. `mcp-readonly`

## Initiative-wide boundaries

- Financial records remain in the user's private iCloud account.
- The MCP server exposes read operations only and cannot mutate records or execute trades.
- Real-estate assets and prescriptive AI-advisor behavior are outside the initial scope.
- Market-data providers remain replaceable behind a typed interface.
- Development stops at each module checkpoint for hands-on user testing.
- `savings-deposit` and `fund-etf-holdings` share one Investments tab. That tab
  is a screen, not a module.
- `recurring-transactions` writes ordinary `MoneyTransaction` records and holds
  no balance of its own, so it adds no term to any total. It runs when the app is
  opened, never on a timer and never in the background.

## Dropped

`investment-tracking` is dropped as a trade ledger, not deferred.

- The owner does not record individual buy/sell trades, so trade execution,
  trade history, realized profit and loss, equities, and crypto have nobody to
  serve.
- Physical gold holdings are shipped through the existing catalogue-and-position
  shape: quantity and cost basis live on `FundHolding`, current shop-buy value
  lives on `FundInstrument`, and the Home allocation gives gold its own wedge.
- A shared `Instrument` abstraction remains dropped. `FundInstrument` now covers
  funds, ETFs, and gold; renaming that established model would add migration and
  code churn without changing behavior.
