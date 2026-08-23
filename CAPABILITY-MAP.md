# Capability Map: MonMon

MonMon is a private, Apple-platform personal asset manager. Each module below is a
small vertical feature that includes the minimum domain logic, storage, UI, and
tests needed for the owner to try it on iPhone and Mac before the next module
begins.

| Module id | User-visible responsibility | Depends on |
|---|---|---|
| `app-bootstrap` | Build and run a configured native app showing “Hello, MonMon” on iPhone and Mac | — |
| `cash-balance` | Create cash/bank accounts and view their balances | `app-bootstrap` |
| `savings-deposit` | Record term deposits with maturity dates, projected interest, and an optional funding account, and see total assets | `cash-balance` |
| `income-expense` | Record income and expenses and see account balances update | `cash-balance` |
| `debt-tracking` | Track liabilities and liability payments | `cash-balance`, `income-expense` |
| `investment-tracking` | Record gold, equity, and crypto trades and calculate positions and cost basis | `cash-balance`, `income-expense` |
| `market-valuation` | Refresh market prices and show portfolio value, allocation, and profit/loss | `investment-tracking` |
| `icloud-sync` | Synchronize all financial records through the owner's private iCloud database | `cash-balance`, `income-expense`, `debt-tracking`, `investment-tracking`, `market-valuation` |
| `mcp-readonly` | Expose synchronized financial data to AI clients from a read-only macOS MCP server | `icloud-sync` |

Build order:

1. `app-bootstrap`
2. `cash-balance`
3. `savings-deposit`
4. `income-expense`
5. `debt-tracking`
6. `investment-tracking`
7. `market-valuation`
8. `icloud-sync`
9. `mcp-readonly`

## Initiative-wide boundaries

- Financial records remain in the user's private iCloud account.
- The MCP server exposes read operations only and cannot mutate records or execute trades.
- Real-estate assets and prescriptive AI-advisor behavior are outside the initial scope.
- Market-data providers remain replaceable behind a typed interface.
- Development stops at each module checkpoint for hands-on user testing.
