# System: Ledger Engine

> Balance derivation and invariant enforcement

---

## Overview

The LedgerEngine is the core domain logic that ensures financial data consistency. It's the single source of truth for balance calculations and enforces all invariants.

## Design Principles

1. **Balance is derived, never stored** — compute from ledger entries
2. **Single transaction boundary** — all writes are atomic
3. **Invariants enforced at write time** — reject invalid operations early
4. **Void is retrospective** — voided entries remain in history

## Core Operations

### createExpense(input)

```typescript
function createExpense(input: ExpenseInput): Expense {
  // 1. Validate
  validateAmount(input.amount);
  validateCategory(input.category);
  validateWallet(input.walletId);
  
  // 2. Check idempotency
  if (input.clientRequestId) {
    const existing = findByClientRequestId(input.clientRequestId);
    if (existing && samePayload(existing, input)) return existing;
    if (existing) throw new Error('IDEMPOTENCY_CONFLICT');
  }
  
  // 3. Check CC limit
  const wallet = getWallet(input.walletId);
  if (wallet.type === 'credit_card') {
    const newDebt = calculateDebt(wallet) + input.amount;
    if (newDebt > wallet.creditLimit) {
      throw new Error('INSUFFICIENT_AVAILABLE_CREDIT');
    }
  }
  
  // 4. Create expense + ledger entry in single transaction
  return db.transaction(() => {
    const expense = db.insert('expenses', {
      ...input,
      status: 'active',
      createdAt: now(),
      updatedAt: now(),
    });
    
    db.insert('ledgerEntries', {
      walletId: input.walletId,
      type: 'expense',
      amount: -input.amount,
      refId: expense.id,
      refType: 'expense',
      date: input.date,
    });
    
    return expense;
  });
}
```

### createTransfer(input)

```typescript
function createTransfer(input: TransferInput): Transfer {
  // 1. Validate
  if (input.fromWalletId === input.toWalletId) {
    throw new Error('TRANSFER_SAME_WALLET');
  }
  validateAmount(input.amount);
  
  // 2. Check idempotency
  if (input.clientRequestId) {
    const existing = findByClientRequestId(input.clientRequestId);
    if (existing && samePayload(existing, input)) return existing;
    if (existing) throw new Error('IDEMPOTENCY_CONFLICT');
  }
  
  // 3. Create transfer + 2 ledger entries in single transaction
  return db.transaction(() => {
    const transfer = db.insert('transfers', {
      ...input,
      status: 'active',
      createdAt: now(),
    });
    
    // Outgoing
    db.insert('ledgerEntries', {
      walletId: input.fromWalletId,
      type: 'transfer_out',
      amount: -input.amount,
      refId: transfer.id,
      refType: 'transfer',
      date: input.date,
    });
    
    // Incoming
    db.insert('ledgerEntries', {
      walletId: input.toWalletId,
      type: 'transfer_in',
      amount: input.amount,
      refId: transfer.id,
      refType: 'transfer',
      date: input.date,
    });
    
    return transfer;
  });
}
```

### voidExpense(id)

```typescript
function voidExpense(id: string): void {
  const expense = db.findById('expenses', id);
  if (!expense) throw new Error('NOT_FOUND');
  if (expense.status === 'voided') throw new Error('ALREADY_VOIDED');
  
  db.transaction(() => {
    // Soft void
    db.update('expenses', id, { status: 'voided', updatedAt: now() });
    
    // Mark ledger entry as voided
    db.update('ledgerEntries', { refId: id, refType: 'expense' }, { status: 'voided' });
  });
}
```

### getWalletBalance(walletId)

```typescript
function getWalletBalance(walletId: string): number {
  const result = db.query(`
    SELECT COALESCE(SUM(amount), 0) as balance
    FROM ledgerEntries
    WHERE walletId = ?
    AND status = 'active'
  `, [walletId]);
  
  return result.balance;
}
```

### getCreditCardInfo(walletId)

```typescript
function getCreditCardInfo(walletId: string): {
  debt: number;
  available: number;
  creditLimit: number;
} {
  const wallet = getWallet(walletId);
  const debt = calculateDebt(wallet);
  
  return {
    debt,
    available: wallet.creditLimit - debt,
    creditLimit: wallet.creditLimit,
  };
}
```

## Invariant Enforcement

| Invariant | Where Enforced |
|-----------|----------------|
| Balance derived | Always computed from ledger |
| Transfer atomicity | `createTransfer` transaction |
| No negative money | `validateAmount` |
| CC limit | `createExpense` checks debt before insert |
| Void exclusion | `getWalletBalance` filters `status = active` |
| Idempotency | Check `clientRequestId` before insert |

## Ledger Entry Lifecycle

```
Create → Active → [Voided]
                → [Never voided, stays active forever]
```

## Balance Calculation

### For Regular Wallets

```
balance = Σ(ledgerEntries.amount WHERE walletId = ? AND status = 'active')
```

### For Credit Cards

```
debt = Σ(expense amounts WHERE wallet = CC AND status = 'active')
     − Σ(transfer amounts TO CC AND status = 'available')
available = creditLimit − debt
```

## Reconciliation

Periodically verify:
```
wallet.balance == SUM(ledgerEntries for wallet)
```

If mismatch:
- Log error
- Trigger recalculation
- Alert user

## Testing

- Unit tests for each operation
- Invariant tests (never drift)
- Concurrency tests (simultaneous writes)
- Idempotency tests
