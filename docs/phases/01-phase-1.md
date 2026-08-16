# Phase 1 — Foundation (MVP)

> iPhone + Mac, local SQLite, manual entry, basic dashboard, MCP

---

## 🎯 Goal

Ship a working expense tracker on iPhone (primary) and Mac (secondary) with:
- Manual expense/income entry
- Wallet management (Cash/Bank/E-wallet/Credit Card)
- Transfer between wallets
- Basic dashboard (cash flow, category %, savings rate)
- MCP server for AI agent access
- Local-only data (no sync)

---

## 📋 Scope

### Clients
- **iPhone** (Expo React Native) — primary
- **Mac** (Expo Web wrapper) — secondary, same codebase
- **MCP Server** (Node.js/TS) — runs on Mac, reads local SQLite

### Features
- Wallet CRUD (Cash/Bank/E-wallet/Credit Card)
- Transfer between wallets
- Expense/Income manual entry
- Soft void + Edit
- Dashboard: Cash flow + Category % + Savings rate + Wallet balances
- Monthly report (basic)
- Onboarding (default wallets, VND categories, sample data)
- Daily reminder notification
- Local auth (Face ID / system auth)
- Export CSV / Backup JSON
- Custom app icon

### MCP Tools (9)
- `add_expense`, `update_expense`, `void_expense`
- `add_income`, `update_income`, `void_income`
- `get_wallets`, `transfer`, `search_transactions`

---

## 🔒 Invariants

1. **Balance derived:** `Wallet.balance` = Σ(income active) − Σ(expense active) + Σ(transfer in) − Σ(transfer out) + opening_balance
2. **CC payment ≠ expense:** `transfer(from=bank, to=cc)` = debt settlement
3. **Soft void:** Record kept in history, excluded from metrics
4. **Idempotency:** `clientRequestId` prevents duplicate writes
5. **Conservation (transfer):** `amount_out == amount_in`, atomic 2 legs
6. **Metrics hygiene:** Only active expense+income. Exclude transfer, voided, opening_balance
7. **CC balance:** `debt = Σ(expense CC) − Σ(payments CC)`, `available = creditLimit − debt`
8. **Currency:** VND only
9. **Timezone:** Asia/Ho_Chi_Minh fixed
10. **Void transfer:** Void both legs or reject
11. **No negative money:** No negative expense/income
12. **Credit limit:** Hard block
13. **Income to CC wallet:** Reject

---

## 📅 Checklist

```
[ ] Setup monorepo (npm workspaces)
[ ] Shared types (Expense, Income, Wallet, Transfer)
[ ] Mobile scaffold (Expo Router, iPhone + Mac)
[ ] Local SQLite + ledger logic
[ ] Manual expense entry UI
[ ] Manual income entry UI
[ ] Wallet management UI
[ ] Transfer between wallets UI
[ ] Soft void + Edit UI
[ ] Onboarding (default wallets, VND categories, sample data)
[ ] Dashboard: Cash flow + Category % + Savings rate + Wallet balances
[ ] Monthly report (basic)
[ ] Daily reminder notification
[ ] Local auth (Face ID / system auth)
[ ] Export CSV / Backup JSON
[ ] MCP Server: 9 tools + Resources + Structured errors
[ ] MCP dry-run + idempotency
[ ] EXPENSE_MCP_READONLY env support
[ ] Custom app icon
[ ] MCP config block cho Claude Code / Codex
```

---

## 📝 Design Docs

- Feature: Wallets → `features/01-wallets.md`
- Feature: Expenses → `features/02-expenses.md`
- Feature: Dashboard → `features/03-dashboard.md`
- Feature: MCP Server → `features/04-mcp-server.md`
- Feature: Onboarding → `features/05-onboarding.md`
- Feature: Sync/Export → `features/06-sync.md`
- System: Data Model → `system/01-data-model.md`
- System: Architecture → `system/02-architecture.md`
- System: Ledger Engine → `system/03-ledger.md`
- System: MCP Protocol → `system/04-mcp-protocol.md`
- System: Security → `system/06-security.md`
- System: Backup → `system/07-backup.md`
