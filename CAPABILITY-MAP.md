# Capability Map: MonMon

MonMon is a private, Apple-platform personal asset manager. Each module below is a
small vertical feature that includes the minimum domain logic, storage, UI, and
tests needed for the owner to try it on iPhone and Mac before the next module
begins.


| Module id                 | User-visible responsibility                                                                                                                                            | Depends on                                                                                 |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `app-bootstrap`           | Build and run a configured native app on iPhone and Mac, with a Settings tab for the theme and an optional biometric lock                                              | —                                                                                          |
| `cash-balance`            | Create, edit, and delete cash, bank, and credit card accounts and view their balances                                                                                  | `app-bootstrap`                                                                            |
| `savings-deposit`         | Record term deposits with maturity dates, projected interest, and an optional funding account, and see total assets                                                    | `cash-balance`                                                                             |
| `fund-etf-holdings`       | Record fund certificate and ETF holdings at a hand-entered NAV and see cost basis, market value, and unrealized profit or loss                                         | `cash-balance`, `savings-deposit`                                                          |
| `income-expense`          | Record income and expenses against one account each, under owner-managed categories, and see account balances update. Transfers between accounts are out of scope      | `cash-balance`                                                                             |
| `account-transfer`        | Move money between two of the owner's own accounts, so both balances follow and total assets stay put                                                                  | `cash-balance`, `income-expense`                                                           |
| `debt-tracking`           | Record money borrowed and money lent out, with the payments against them, so balances follow and total assets stay put                                                 | `cash-balance`, `income-expense`, `account-transfer`                                       |
| `~~investment-tracking~~` | **Dropped.** Would have recorded gold, equity, and crypto trades and calculated positions and cost basis. The owner does not trade, so the module has no user          | —                                                                                          |
| `market-valuation`        | Refresh market prices for the fund catalogue and show what a holding is worth. Slice 1 shipped; slice 2 is dropped with `investment-tracking`                          | `fund-etf-holdings`                                                                        |
| `icloud-sync`             | Synchronize all financial records through the owner's private iCloud database                                                                                          | `cash-balance`, `income-expense`, `debt-tracking`, `fund-etf-holdings`, `market-valuation` |
| `mcp-readonly`            | Expose synchronized financial data to AI clients from a read-only macOS MCP server                                                                                     | `icloud-sync`                                                                              |


Build order:

1. `app-bootstrap`
2. `cash-balance`
3. `savings-deposit`
4. `fund-etf-holdings`
5. `income-expense`
6. `account-transfer`
7. `debt-tracking`
8. `market-valuation` — slice 1 only
9. `icloud-sync`
10. `mcp-readonly`

## Initiative-wide boundaries

- Financial records remain in the user's private iCloud account.
- The MCP server exposes read operations only and cannot mutate records or execute trades.
- Real-estate assets and prescriptive AI-advisor behavior are outside the initial scope.
- Market-data providers remain replaceable behind a typed interface.
- Development stops at each module checkpoint for hands-on user testing.
- `savings-deposit` and `fund-etf-holdings` share one Investments tab. That tab
is a screen, not a module.

## Dropped

`investment-tracking` is dropped, not deferred. 

- The owner does not trade gold, equities, or crypto, so a module for recording those trades has nobody to serve.
- Two things followed from it and are dropped with it: slice 2 of
  `market-valuation` — portfolio-wide allocation and profit and loss across
  asset classes — and any shared `Instrument` abstraction, which had been left
  for `investment-tracking` to decide. `FundInstrument` covers funds and ETFs
  and now covers everything the app values.
