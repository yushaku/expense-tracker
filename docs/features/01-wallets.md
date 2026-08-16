# Feature: Wallets

> Wallet CRUD, Transfer, Opening balance

---

## Overview

Users can manage multiple wallets representing their cash, bank accounts, e-wallets, and credit cards. Wallets are the source of truth for where money sits.

## Wallet Types

| Type | Description | Balance Semantics |
|------|-------------|-------------------|
| `cash` | Physical cash | Positive |
| `bank` | Bank account (checking/savings) | Positive |
| `ewallet` | Momo, ZaloPay, v.v. | Positive |
| `credit_card` | Credit card with limit | Debt (negative display) |

## Operations

### Create Wallet
- Input: `name`, `type`, `currency` (VND), `creditLimit` (if CC), `openingBalance`
- Validation: `openingBalance >= 0`, `creditLimit > 0` if CC
- Effect: Creates wallet + ledger entry `opening_balance`

### Update Wallet
- Input: `name`, `creditLimit` (if CC)
- Cannot change `type` or `currency`

### Get Wallets
- Returns all wallets with derived balance

### Transfer Between Wallets
- Input: `fromWalletId`, `toWalletId`, `amount`, `date`, `note`, `dryRun`, `clientRequestId`
- Validation: `from != to`, `amount > 0`, `from.balance >= amount` (except CC), idempotency
- Effect: Two ledger entries (`transfer_out`, `transfer_in`), atomic

## Credit Card Semantics

```
Spending:     add_expense(wallet=cc)        → debt increases
Payment:      transfer(from=bank, to=cc)    → debt decreases
Available:    creditLimit - debt
```

- **Hard block:** Cannot spend beyond `creditLimit`
- **Income to CC:** Reject (CC is debt, not income destination)

## Opening Balance

- When creating a user can set initial balance
- Stored as `ledger entry` type `opening_balance`
- Not an expense or income — excluded from cash flow

## Derived Balance

```
balance = Σ(income active to wallet)
        - Σ(expense active from wallet)
        + Σ(transfer in active)
        - Σ(transfer out active)
        + opening_balance
```

- Balance is NEVER stored directly on wallet
- Always computed from ledger
- Voided transactions excluded

## Data Model

```
Wallet
├── id: uuid
├── name: string
├── type: enum [cash, bank, ewallet, credit_card]
├── currency: string (VND)
├── creditLimit: number (CC only, 0 for others)
├── createdAt, updatedAt: ISO datetime
└── balance: DERIVED (not stored)
```

## UI Screens

- `/wallets` — list wallets with balance, type icon
- `/wallets/[id]` — detail, recent transactions
- `/wallets/new` — create form
- `/wallets/[id]/edit` — edit form
- `/transfer` — transfer between wallets

## MCP Tools

| Tool | Description |
|------|-------------|
| `get_wallets` | List all wallets with balance |
| `transfer` | Transfer between wallets |

## Edge Cases

- Transfer to same wallet → reject
- Transfer more than balance (non-CC) → allow (overdraft) or warn
- CC spending over limit → hard block
- Income to CC wallet → reject
- Void transfer → void both legs or reject
