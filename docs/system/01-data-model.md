# System: Data Model

> Entities, relationships, invariants

---

## Overview

Core data entities and their relationships.

## Entities

### Core (Phase 1)

| Entity | Description |
|--------|-------------|
| Wallet | Cash/Bank/E-wallet/Credit Card accounts |
| Expense | Money spent |
| Income | Money received |
| Transfer | Money movement between wallets |
| LedgerEntry | Internal accounting entries |

### Phase 1.5 Additions

| Entity | Description |
|--------|-------------|
| Budget | Spending limits |
| Investment | Assets (gold, crypto, ETF, etc.) |
| RecurringExpense | Scheduled auto-generated expenses |

### Phase 2-3 Additions

| Entity | Description |
|--------|-------------|
| Currency | Supported currencies |
| ExchangeRate | Conversion rates |
| User | Multi-user support |
| Family | Group of users |

## Relationships

```
Wallet 1 ──── * Expense
Wallet 1 ──── * Income
Wallet 1 ──── * Transfer (from)
Wallet 1 ──── * Transfer (to)
Wallet 1 ──── * LedgerEntry

Family 1 ──── * FamilyMember
FamilyMember * ──── 1 User

Budget * ──── 1 Wallet (optional)
Investment (standalone)
RecurringExpense * ──── 1 Wallet
```

## Ledger Entry Types

| Type | Description | Effect on Balance |
|------|-------------|-------------------|
| `expense` | Money out | − amount |
| `income` | Money in | + amount |
| `transfer_out` | Money moved out | − amount |
| `transfer_in` | Money moved in | + amount |
| `opening_balance` | Initial balance | + amount |

## Balance Derivation

```
Wallet.balance = Σ(
  LedgerEntry.amount
  WHERE walletId = wallet.id
  AND status = active
)
```

Where:
- `expense` → amount is negative
- `income` → amount is positive
- `transfer_out` → amount is negative
- `transfer_in` → amount is positive
- `opening_balance` → amount is positive

## Invariants

1. **Balance consistency:** Balance always equals sum of active ledger entries
2. **Transfer atomicity:** Every transfer creates exactly 2 entries (out + in)
3. **No negative money:** expense.amount > 0, income.amount > 0
4. **Void exclusion:** voided entries excluded from balance and metrics
5. **CC limit:** CC balance cannot exceed creditLimit
6. **Currency consistency:** All amounts in same wallet have same currency (Phase 1: VND only)

## Soft Delete (Void)

- Expense/Income: `status: voided`, kept in history
- Transfer: both legs voided or rejected
- Budget/Investment: hard delete

## Data Types

### Enums

```typescript
type WalletType = 'cash' | 'bank' | 'ewallet' | 'credit_card';
type ExpenseCategory = 'food' | 'transport' | 'shopping' | 'entertainment' | 'healthcare' | 'education' | 'bills' | 'savings' | 'other';
type IncomeType = 'salary' | 'freelance' | 'investment' | 'gift' | 'other';
type TransactionStatus = 'active' | 'voided';
type LedgerEntryType = 'expense' | 'income' | 'transfer_out' | 'transfer_in' | 'opening_balance';
type BudgetPeriod = 'weekly' | 'monthly' | 'yearly';
type InvestmentType = 'gold' | 'real_estate' | 'fund' | 'crypto' | 'etf' | 'bond' | 'stock' | 'other';
type RecurringFrequency = 'daily' | 'weekly' | 'monthly' | 'yearly';
```

### IDs

All IDs are UUID v4 or similar unique strings (e.g., `Date.now().toString(36) + Math.random().toString(36).substr(2, 9)`)

## Storage

- SQLite database file
- Path (macOS): `~/Library/Application Support/expense-tracker/expenses.db`
- Path (iOS): App document directory
- Schema migrations tracked via `user_version` pragma

## Indexes

```sql
CREATE INDEX idx_expenses_wallet ON expenses(walletId);
CREATE INDEX idx_expenses_date ON expenses(date);
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_status ON expenses(status);
CREATE INDEX idx_income_wallet ON income(walletId);
CREATE INDEX idx_income_date ON income(date);
CREATE INDEX idx_ledger_wallet ON ledgerEntry(walletId);
CREATE INDEX idx_ledger_ref ON ledgerEntry(refId, refType);
CREATE INDEX idx_transfers_from ON transfer(fromWalletId);
CREATE INDEX idx_transfers_to ON transfer(toWalletId);
```
