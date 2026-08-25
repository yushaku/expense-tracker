# Savings withdrawal and settlement

## Product rules

- Reaching the maturity date changes a savings book to **matured** but does not move money.
- The owner settles a matured book manually by recording what the bank actually paid.
- The same withdrawal record supports partial withdrawal, full early withdrawal, and maturity settlement.
- Every withdrawal names the principal removed, the amount actually received, the date, and the cash account that received it.
- A partial withdrawal leaves the original rate, term, and maturity date unchanged for the remaining principal.
- Once any withdrawal exists, only the savings-book name can be edited. Its financial terms stay locked so history cannot be rewritten.
- A book with no remaining principal is **settled**. It remains visible at the bottom of the list as dimmed history.
- Deleting a savings book also deletes its withdrawal history. Deleting one withdrawal restores its principal and reverses its cash flow.

## Accounting

`SavingsDeposit.principal` is the immutable opening principal. Current savings value is:

```text
remaining principal = opening principal - sum(withdrawal principal)
```

The destination cash account receives `amountReceived`, not the principal removed. Realized interest or loss is:

```text
realized interest = amount received - principal removed
```

Projected interest remains informational and is never counted in net worth. A withdrawal changes net worth only by its realized interest or loss because the removed principal moves from savings to cash exactly once.

## States

```text
remaining principal <= 0       -> settled
otherwise, today >= maturity   -> matured
otherwise                      -> active
```

Matured books are listed first because they need action, active books next, and settled books last.

## Out of scope

- Automatic settlement at maturity
- Automatic renewal or rollover
- Bank synchronization
- Recalculating a bank's early-withdrawal interest policy

The app suggests the contractual maturity value, but the owner's confirmed bank receipt is authoritative.
