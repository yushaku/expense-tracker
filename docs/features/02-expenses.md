# Feature: Expenses & Income

> Expense/Income CRUD, Soft void, Edit

---

## Overview

Users manually record expenses and income. Each is linked to a wallet. Soft void allows undo without losing history.

## Expense

### Fields
- `amount`: positive number
- `currency`: VND (Phase 1)
- `category`: enum [food, transport, shopping, entertainment, healthcare, education, bills, savings, other]
- `description`: free text
- `date`: ISO datetime (Asia/Ho_Chi_Minh)
- `walletId`: FK → Wallet
- `merchant`: optional (from OCR)
- `receiptImage`: optional file path
- `status`: enum [active, voided]
- `clientRequestId`: idempotency key

### Categories (VND, fixed Phase 1)

| Category | Label |
|----------|-------|
| food | Ăn uống |
| transport | Di chuyển |
| shopping | Mua sắm |
| entertainment | Giải trí |
| healthcare | Y tế |
| education | Giáo dục |
| bills | Hóa đơn |
| savings | Tiết kiệm (transfer to savings wallet, not expense) |
| other | Khác |

### Income

### Fields
- `amount`: positive number
- `currency`: VND (Phase 1)
- `source`: string (lương, thu nhập phụ, đầu tư)
- `description`: free text
- `date`: ISO datetime (Asia/Ho_Chi_Minh)
- `walletId`: FK → Wallet
- `type`: enum [salary, freelance, investment, gift, other]
- `status`: enum [active, voided]
- `clientRequestId`: idempotency key

## Operations

### Add Expense/Income
- Input: amount, category/source, description?, date?, walletId, merchant?, dryRun?, clientRequestId
- Validation: amount > 0, valid category, wallet exists
- Idempotency: `clientRequestId` prevents duplicate
- Effect: Creates record + ledger entry + updates wallet balance (derived)

### Update Expense/Income
- Input: id, amount?, category?, description?, date?
- Cannot update voided records
- Cannot change walletId (void + recreate instead)
- Effect: Updates record + recalculates ledger

### Soft Void
- Input: id
- Effect: Sets `status: voided`, keeps in history
- Voided records excluded from:
  - Balance calculation
  - Cash flow
  - Category breakdown
  - Savings rate
  - Monthly report totals

### Search Transactions
- Input: from?, to?, walletId?, category?, type?, text?, includeVoided?, limit?, offset?
- Returns: list of expense+income with type discriminator

## Validation Rules

| Rule | Error |
|------|-------|
| amount <= 0 | VALIDATION_ERROR |
| invalid category | VALIDATION_ERROR |
| wallet not found | NOT_FOUND |
| update voided record | ALREADY_VOIDED |
| duplicate clientRequestId | IDEMPOTENCY_CONFLICT |
| CC spend over limit | INSUFFICIENT_AVAILABLE_CREDIT |

## UI Screens

- `/` — home: recent transactions list
- `/add` — add expense/income form
- `/transactions/[id]` — detail view
- `/transactions/[id]/edit` — edit form
- `/transactions` — search/list with filters

## MCP Tools

| Tool | Description |
|------|-------------|
| `add_expense` | Add expense |
| `update_expense` | Update expense |
| `void_expense` | Soft void expense |
| `add_income` | Add income |
| `update_income` | Update income |
| `void_income` | Soft void income |
| `search_transactions` | Search expense+income |

## Edge Cases

- Expense from wallet with insufficient balance → allow (overdraft)
- Income to CC wallet → reject
- Void already voided record → error ALREADY_VOIDED
- Update voided record → error ALREADY_VOIDED
- Search with no filters → return recent 50
- includeVoided=true → include voided in results
