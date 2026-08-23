# Spec: account-transfer

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `cash-balance`, `income-expense`

## Objective

Let the owner record money moved between two of their own accounts — bank to
wallet, wallet to credit card payment, one bank to another — and see both
balances move by exactly that amount while total assets stay put.

Until now `income-expense` handled only money entering or leaving the owner's
hands. Recording an internal move as an expense on one account and income on
another would work arithmetically but lie twice: it would inflate the month's
income and expense totals, and it would file household money under a spending
category it never belonged to. A transfer is therefore its own record, with no
category and no place in the Spending totals.

Debts, budgets, scheduled transfers, and transfer fees stay in later modules.

## Scope

### User flow

1. Open the **Home** tab and choose **Transfers** from the toolbar.
2. See every recorded transfer, newest first, with the total moved, or an empty
   state when none exists. With fewer than two accounts, see a placeholder that
   says a transfer needs somewhere to leave and somewhere to land.
3. Choose **Add Transfer**.
4. Enter an amount, pick the account the money left and the account it reached,
   choose the date, and optionally write a note. **Swap** exchanges the two ends.
5. Save and return to the list.
6. On the **Home** tab, see the source account's available balance fall by the
   amount, the destination account's rise by it, and total assets unchanged.
7. Tap a transfer to edit every field, or delete it after a confirmation; both
   balances return to what they were.
8. Relaunch on the same device and see the same transfers.

### Included

- Add, edit, and delete transfers between two existing cash, bank, or credit
  accounts.
- A required, distinct source account and destination account.
- A source-balance guard: a transfer may not take more than the account can hand
  over, except from an account allowed to go negative, which is a credit card.
- Both account balances and total assets derived from the stored transfers.
- Blocked account deletion while any transfer names the account, on either end.
- One currency: VND.
- Local SwiftData persistence for `AccountTransfer`.
- Empty, too-few-accounts, populated, validation-error, and persistence-error
  states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Transfer fees, foreign exchange, and any transfer that is not VND to VND.
- Transfers into or out of a savings deposit or a fund holding; the existing
  funding link owns that money.
- Scheduled or recurring transfers, and splitting one transfer across accounts.
- Any appearance in the Spending screen's income, expense, net, or category
  breakdown.
- Automatic pairing of an existing income and expense into one transfer.

## Domain and Data Contract

`AccountTransfer`, a SwiftData `@Model`:

| Field | Type | Rule |
|---|---|---|
| `id` | `UUID` | Assigned once |
| `amount` | `Decimal` | Always positive |
| `occurredAt` | `Date` | Any date, past or future |
| `note` | `String` | Optional, trimmed |
| `sourceAccountID` | `UUID` | Required; the account the money left |
| `destinationAccountID` | `UUID` | Required; differs from the source |
| `currencyCode` | `String` | Always `VND` |
| `createdAt` | `Date` | Assigned once |

The pair of accounts carries the direction, so no call site has to agree on a
sign convention — the same rule `MoneyTransaction` follows with `kind`.
`signedAmount(for:)` answers what a transfer does to one account: negative on
the way out, positive on the way in, zero everywhere else.

Both ends are stored as identifiers rather than relationships, matching the
funding links `SavingsDeposit` and `FundHolding` already use.

### Cash flow and balances

`CashBalanceSummary.available(for:deposits:holdings:transactions:transfers:)`
becomes:

```
openingBalance
  + net recorded transaction flow
  + net transfer flow
  − money funding savings deposits and fund holdings
```

`transfers` has no default value, for the same reason `transactions` has none: a
forgotten argument would silently misreport a spendable balance.

Summed across every account, transfer flow is zero — one account's outflow is
another's inflow. `CashBalanceSummary.totalAvailable`, `AssetSummary.netWorth`,
and the Home doughnut therefore move money between wedges without changing the
total. A transfer out of a credit card drives it negative, which
`AssetAllocation.debt` reports the same way an overspent card already is.

### Account deletion

An account may only be deleted once nothing points at it. The existing guard
already requires a zero available balance and zero transactions; it now also
requires zero transfers, counted on either end. A transfer names two accounts,
and deleting one end would leave the other pointing at nothing.

### Form boundary

`TransferDraft` validates external text before any model is written, in this
order, throwing the first failure:

| Error | Cause |
|---|---|
| `invalidAmount` | The amount does not parse as VND |
| `nonPositiveAmount` | The amount is zero or negative |
| `missingSourceAccount` | No account picked to move from |
| `missingDestinationAccount` | No account picked to move to |
| `sameAccount` | Both ends are the same account |
| `insufficientSourceBalance` | More than the source account can hand over |

`availableSourceBalance` is `nil` — no cap — when no source is picked yet or the
source account is allowed to go negative. When editing, the caller adds this
transfer's own amount back, so re-saving an unchanged amount is never reported
as an overdraft. This mirrors `SavingsDraft` and `FundDraft`.

## UI Contract

- **Transfers** opens from the Home toolbar as a sheet, the way **Categories**
  opens from the Spending toolbar, and it owns its own navigation stack.
- The list shows the total moved, the transfer count, and one card per transfer,
  newest first.
- A card reads "From account to account", carries the note or "Internal
  transfer", and shows the amount with no sign and no gain or loss colour: an
  internal transfer is neither. The two account names carry the direction.
- The editor shows an amount card, a route card with **From**, **To**, and
  **Swap**, and a details card with the date and note.
- Validation errors appear inline beneath the field that caused them.
- Accessibility identifiers: `transfer-list`, `add-transfer`, `manage-transfers`,
  `transfer-<id>`, `transfer-amount`, `transfer-source-account`,
  `transfer-destination-account`, `swap-transfer-accounts`, `transfer-date`,
  `transfer-note`, `save-transfer`, `cancel-transfer`, `delete-transfer`,
  `confirm-delete-transfer`, and the error identifiers `transfer-amount-error`,
  `transfer-route-error`, `save-transfer-error`.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount`,
  `SavingsDeposit`, `FundHolding`, `TransactionCategory`, `MoneyTransaction`,
  and `AccountTransfer`.
- Lists use SwiftData `@Query`; the editor takes `ModelContext` from the
  environment, inserts only after validation, and calls `save()` explicitly,
  rolling back and surfacing the error when it fails.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database.
- Adding one model is an additive schema change; the existing local store opens
  without migration work.

## Testing Strategy

Automated:

- `TransferDraftTests` — every `TransferFormError` case, an amount equal to the
  source balance allowed, a transfer to draft round trip, `swapEnds()`, and
  editing through `apply(to:availableSourceBalance:)`.
- `TransferSummaryTests` — net flow on both ends and on an untouched account,
  opposite transfers cancelling, both ends counted for their account, range
  filtering, a moved balance leaving the total and net worth unchanged, and a
  credit card driven negative reported as debt.
- `AccountTransferPersistenceTests` — field round trip, both balances moved,
  delete restoring both, transactions and transfers stacking on one account, and
  a transfer staying out of the Spending totals.
- Existing cash-balance, savings-deposit, fund, and income-expense tests must
  keep passing with the widened balance signatures.

Hands-on, owned by the owner:

- Recording a transfer and watching one balance fall, the other rise, and total
  assets hold still.
- Editing and deleting a transfer and watching both balances return.
- An overdraft attempt from a bank account being refused, and the same amount
  from a credit card being allowed.
- Blocked account deletion while a transfer names the account.
- Relaunch persistence, iPhone Dynamic Type and keyboards, Mac window resizing.

No automated test may depend on network access, iCloud, current locale,
wall-clock time, or the owner's real app database.

## Verification Commands

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
rtk swift format lint --strict --recursive MonMon MonMonTests
```

## Boundaries

### Always do

- Validate input before inserting or mutating a SwiftData model.
- Keep `openingBalance` untouched; derive available balances instead.
- Store `amount` positive and let the pair of accounts carry direction.
- Require two different accounts on every transfer.
- Preserve exact `Decimal` values and format VND consistently.
- Keep both platform builds healthy after every increment.

### Ask first

- Add transfer fees, foreign exchange, or scheduled transfers.
- Let a transfer touch a savings deposit or a fund holding.
- Show transfers anywhere on the Spending screen.
- Change persisted schema, user flow, copy language, or accessibility
  identifiers.
- Enable iCloud.

### Never do

- Record an internal transfer as an income and an expense pair.
- Give a transfer a category.
- Let a transfer count towards income, expense, net, or the category breakdown.
- Use `Double` or `Float` for money.
- Mutate an account's opening balance to represent a transfer.
- Leave a transfer pointing at a deleted account.

## Success Criteria

- A valid transfer saves, lowers the source account's available balance by
  exactly its amount, and raises the destination account's by the same amount.
- Total assets and net worth are identical before and after any transfer.
- Invalid input does not save and produces a clear inline error, including a
  transfer to the same account and one larger than the source can hand over.
- Editing and deleting a transfer return both balances to a hand-calculated
  figure.
- The Spending screen's income, expense, net, and category breakdown are
  unchanged by any transfer.
- An account named by a transfer cannot be deleted, and the reason names the
  count.
- Transfers survive relaunch on the same device.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

None. Any new requirement moves back through spec approval before implementation.
