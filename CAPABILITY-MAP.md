# Capability Map: MonMon

MonMon is a private, Apple-platform personal asset manager. Each module below is a
small vertical feature that includes the minimum domain logic, storage, UI, and
tests needed for the owner to try it on iPhone and Mac before the next module
begins.

| Module id | User-visible responsibility | Depends on |
|---|---|---|
| `app-bootstrap` | Build and run a configured native app showing “Hello, MonMon” on iPhone and Mac | — |
| `cash-balance` | Create, edit, and delete cash, bank, and credit card accounts and view their balances | `app-bootstrap` |
| `savings-deposit` | Record term deposits with maturity dates, projected interest, and an optional funding account, and see total assets | `cash-balance` |
| `fund-etf-holdings` | Record fund certificate and ETF holdings at a hand-entered NAV and see cost basis, market value, and unrealized profit or loss | `cash-balance`, `savings-deposit` |
| `income-expense` | Record income and expenses against one account each, under owner-managed categories, and see account balances update. Transfers between accounts are out of scope | `cash-balance` |
| `debt-tracking` | Track liabilities and liability payments | `cash-balance`, `income-expense` |
| `investment-tracking` | Record gold, equity, and crypto trades and calculate positions and cost basis | `cash-balance`, `income-expense`, `fund-etf-holdings` |
| `market-valuation` | Refresh market prices and show portfolio value, allocation, and profit/loss | `investment-tracking` |
| `icloud-sync` | Synchronize all financial records through the owner's private iCloud database | `cash-balance`, `income-expense`, `debt-tracking`, `fund-etf-holdings`, `investment-tracking`, `market-valuation` |
| `mcp-readonly` | Expose synchronized financial data to AI clients from a read-only macOS MCP server | `icloud-sync` |

Build order:

1. `app-bootstrap`
2. `cash-balance`
3. `savings-deposit`
4. `fund-etf-holdings`
5. `income-expense`
6. `debt-tracking`
7. `investment-tracking`
8. `market-valuation`
9. `icloud-sync`
10. `mcp-readonly`

## Initiative-wide boundaries

- Financial records remain in the user's private iCloud account.
- The MCP server exposes read operations only and cannot mutate records or execute trades.
- Real-estate assets and prescriptive AI-advisor behavior are outside the initial scope.
- Market-data providers remain replaceable behind a typed interface.
- Development stops at each module checkpoint for hands-on user testing.
