# System: Ledger and Accounting

## Rules

Money is stored as 64-bit integer minor units. Commands accept decimal strings, never floating-point values. Ledger rows are append-only except for an atomic status transition from `active` to `voided`; corrections append operations and replacement entries.

Signed entry effects:

| Entry kind        |    Non-credit wallet |  Credit card debt effect |
| ----------------- | -------------------: | -----------------------: |
| `opening_balance` | signed opening asset |      signed opening debt |
| `income`          |            `+amount` |              not allowed |
| `expense`         |            `-amount` |                `+amount` |
| `transfer_out`    |            `-amount` |    payment reversal only |
| `transfer_in`     |            `+amount` | `-amount` (card payment) |

`amountMinor` on source entities is positive. `signedMinor` on ledger entries carries the projection sign. Currency must equal the wallet currency.

## Formulas

```text
assetBalance(wallet) = Σ active LedgerEntry.signedMinor
creditCardDebt(card) = Σ active expense amounts to card
                     - Σ active payment amounts to card
availableCredit(card) = creditLimitMinor - creditCardDebt(card)
netWorth = Σ non-credit asset balances + Σ investment current values
         - Σ credit-card debts
cashFlow(period) = income - expenses          # transfers excluded
```

Refunds are explicit refund operations, not negative expenses. Overpayment may make card debt negative only if product policy permits; `availableCredit` then exceeds the nominal limit and UI labels the credit balance.

## Posting transactions

- Expense: source row + one ledger expense row + operation in one SQL transaction.
- Income: source row + one ledger income row + operation.
- Transfer: transfer row + exactly two entries (`transfer_out`, `transfer_in`) sharing `transferId`; equal positive magnitude and currency; one operation.
- Card payment: a transfer from an asset wallet to the credit-card wallet. The asset leg decreases assets; card leg decreases debt.
- Void: append void operation and mark source plus every associated active ledger entry voided atomically.
- Update: amount/category/note/date changes append an update operation and replace affected active entry. Wallet/currency changes require void-and-recreate.

## SQL constraints

The full DDL is in the data-model document. Ledger-specific invariants also use transactional repository checks because SQLite `CHECK` cannot validate cross-row two-leg conservation. Foreign keys are enabled on every connection.

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE ledger_entries (
  id TEXT PRIMARY KEY NOT NULL,
  wallet_id TEXT NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  source_type TEXT NOT NULL CHECK (source_type IN ('expense','income','transfer','opening_balance','refund')),
  source_id TEXT NOT NULL,
  entry_kind TEXT NOT NULL CHECK (entry_kind IN ('expense','income','transfer_out','transfer_in','opening_balance','refund')),
  signed_minor INTEGER NOT NULL CHECK (signed_minor != 0),
  currency TEXT NOT NULL CHECK (length(currency) = 3),
  status TEXT NOT NULL CHECK (status IN ('active','voided')),
  occurred_at_utc TEXT NOT NULL CHECK (occurred_at_utc GLOB '*Z'),
  occurred_offset_minutes INTEGER NOT NULL CHECK (occurred_offset_minutes BETWEEN -840 AND 840),
  created_at_utc TEXT NOT NULL CHECK (created_at_utc GLOB '*Z'),
  created_offset_minutes INTEGER NOT NULL CHECK (created_offset_minutes BETWEEN -840 AND 840),
  updated_at_utc TEXT NOT NULL CHECK (updated_at_utc GLOB '*Z'),
  updated_offset_minutes INTEGER NOT NULL CHECK (updated_offset_minutes BETWEEN -840 AND 840),
  UNIQUE(source_type, source_id, entry_kind, wallet_id)
);

CREATE INDEX idx_ledger_wallet_status_time
  ON ledger_entries(wallet_id, status, occurred_at_utc, id);
CREATE INDEX idx_ledger_source ON ledger_entries(source_type, source_id);
```

## Reconciliation

On backup validation, migration, and explicit diagnostics:

1. Recompute projections from active ledger entries.
2. Assert each active transfer has exactly two opposite/equivalent legs.
3. Assert source/ledger amount, currency, status, and wallet agreement.
4. Report orphan or duplicate source keys; do not silently repair.

## Tests

Property tests cover conservation under arbitrary create/update/void sequences, integer overflow boundaries, card purchases/payments/refunds/overpayments, and transfer rollback at every injected failure point.
