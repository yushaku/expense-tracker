# Spec: debt-tracking

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `cash-balance`, `income-expense`, `account-transfer`

## Objective

Let the owner record money borrowed and money lent out — a bank loan, a sum
taken from a relative, a sum handed to one — watch a cash account move by
exactly the principal, record repayments against the debt, and see total assets
stand still through all of it.

Until now the word debt meant one narrow thing in this app: an account spent
past its balance, which `AssetAllocation` reports as a magnitude beneath the
Home doughnut. Money genuinely owed to someone else had nowhere to live, and a
repayment could only be recorded by lying about it — filing it as an expense,
which inflates the month's spending for money that merely changed hands and
files a household obligation under a spending category it never belonged to.
That is the same lie `account-transfer` refused for internal moves, and it is
refused again here. A debt and its payments are therefore their own records,
with no category and no place in the Spending totals.

Both directions live on one model. Money borrowed is a liability and money lent
out is an asset, but they are the same shape — a counterparty, a principal, a
running balance, and a list of payments — and splitting them into two tables
would duplicate every rule so the two copies could disagree.

Budgets, reminders, and instalment schedules stay in later modules.

## Scope

### User flow

1. Open the **Home** tab and choose **Debts** from the toolbar.
2. See the net position, then **Money I owe**, then **Money owed to me**, each
   debt showing what is still outstanding — or an empty state when none exists.
   With no accounts at all, see a placeholder that says a debt needs somewhere
   for the money to land or leave from.
3. Choose **Add Debt**.
4. Pick a direction, name the counterparty, enter the principal, choose the cash
   account the money moved through, and optionally set an annual rate, a due
   date, and a note.
5. Save and return to the list.
6. On the **Home** tab, see a borrowed principal raise its account's available
   balance and the **Owed** figure by the same amount, or a lent principal lower
   its account and appear as a **Lent out** wedge — and see total assets
   unchanged either way.
7. Tap a debt to open it, read what it has cost and what is left, and choose
   **Record Payment**. Enter an amount, or take the whole outstanding balance in
   one tap, and pick the account the money moves through.
8. Save, and see the account move, the outstanding balance fall by the same
   amount, and total assets stay put. A debt paid to nothing reads as settled.
9. Edit or delete a debt or a payment after a confirmation; every balance
   returns to what it was.
10. Relaunch on the same device and see the same debts and payments.

A debt taken before this app existed is recorded with no account. The obligation
is real; the cash movement is not this app's to record, because the borrowed
money is already inside an opening balance.

### Included

- Add, edit, and delete debts in both directions, borrowed and lent.
- Add, edit, and delete payments against a debt.
- An optional cash account on a debt, and a required one on every payment.
- An optional annual rate and an optional due date, with simple interest
  projected for display only.
- What is outstanding derived from the principal and the payments recorded
  against it, and a settled state derived from that.
- A payment cap: a payment may not take a debt past settled.
- A source-balance guard on the two directions that spend money — lending, and
  repaying something borrowed — except from an account allowed to go negative,
  which is a credit card.
- Account balances, total assets, net worth, and the Home doughnut derived from
  the stored debts and payments.
- Blocked account deletion while any debt or payment names the account.
- Deleting a debt deletes the payments that belonged to it.
- One currency: VND.
- Local SwiftData persistence for `Debt` and `DebtPayment`.
- Empty, no-accounts, populated, validation-error, and persistence-error states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Compound interest, interest capitalised onto the balance, reducing-balance
  interest, amortisation schedules, and instalment plans.
- Splitting one payment between interest and principal.
- Reminders, notifications, and any scheduled or recurring payment.
- Foreign exchange and any debt that is not VND to VND.
- A counterparty address book, guarantors, and collateral.
- Debts that fund a savings deposit or a fund holding; the existing funding link
  owns that money.
- Any appearance in the Spending screen's income, expense, net, or category
  breakdown.

## Domain and Data Contract

`Debt`, a SwiftData `@Model`:

| Field | Type | Rule |
|---|---|---|
| `id` | `UUID` | Assigned once |
| `counterparty` | `String` | Required, trimmed, at least one non-whitespace character |
| `direction` | `DebtDirection` | `borrowed` or `lent` |
| `principal` | `Decimal` | Always positive |
| `annualInterestRate` | `Decimal` | Percent per year, in `0...100`; zero is the common case |
| `openedAt` | `Date` | Any date, past or future |
| `dueDate` | `Date?` | Optional; never earlier than `openedAt` |
| `accountID` | `UUID?` | Optional; the account the principal moved through |
| `note` | `String` | Optional, trimmed |
| `currencyCode` | `String` | Always `VND` |
| `createdAt` | `Date` | Assigned once |

`DebtPayment`, a SwiftData `@Model`:

| Field | Type | Rule |
|---|---|---|
| `id` | `UUID` | Assigned once |
| `debtID` | `UUID` | Required; the debt this pays down |
| `amount` | `Decimal` | Always positive |
| `occurredAt` | `Date` | Any date, past or future |
| `accountID` | `UUID` | Required; the account the money moved through |
| `note` | `String` | Optional, trimmed |
| `currencyCode` | `String` | Always `VND` |
| `createdAt` | `Date` | Assigned once |

Rules:

- Both ends are stored as identifiers rather than relationships, matching the
  funding links `SavingsDeposit` and `FundHolding` already use and the two ends
  of an `AccountTransfer`.
- `createdAt` is supplied by the caller so tests do not depend on wall-clock
  time. So is every "today" a calculation needs, passed as `asOf`.
- Money and rates use `Decimal`; `Double` and `Float` are forbidden.

`Debt.accountID` is optional and `DebtPayment.accountID` is not, and the
asymmetry is deliberate. A debt taken before tracking started is already inside
an account's opening balance, so pointing it at an account would credit the same
money twice; recording it unlinked states the obligation without inventing a
cash inflow that never happened. A payment, by contrast, always moves money
now — a debt forgiven rather than paid is a smaller principal, recorded by
editing the debt, not a payment that drops cash nobody handed over.

`DebtPayment.debtID` is not optional, and cannot be. A dangling `categoryID` on
a `MoneyTransaction` is merely untidy, which is why that field is optional and
the screen renders "Uncategorized"; a payment with no debt is *uncomputable*,
because the direction that signs its amount lives on the parent. The orphan
state is therefore made inexpressible, and deletion cascades instead.

### Direction and cash flow

`DebtDirection` carries the direction so every amount can be stored positive and
no call site has to agree on a sign convention — the same rule
`MoneyTransaction` follows with `kind` and `AccountTransfer` with its pair of
accounts.

| Event | Effect on the named account |
|---|---|
| Borrow | Rises by the principal |
| Lend | Falls by the principal |
| Pay back something borrowed | Falls by the payment |
| Be paid back on something lent | Rises by the payment |

`Debt.signedPrincipal` and `DebtPayment.signedAmount(for:)` are the only two
places these four signs are written down. A payment's direction is read from its
parent debt and never copied onto the payment: one record owns that fact, and a
second copy is a fact waiting to drift.

Unlike transfer flow, debt flow does **not** sum to zero across accounts. The
counterparty lives outside the app, so borrowing genuinely adds cash the owner
did not have. That is precisely why net worth needs the outstanding balances as
well — without them, borrowing would look like income.

### Outstanding and settlement

```
outstanding = principal − Σ payments recorded against this debt
```

Outstanding is derived and never stored, and it is deliberately not clamped at
zero. Clamping would let a payment drop cash without dropping what is owed, and
net worth would fall by the excess with no screen explaining why. The form
refuses overpayment instead, so a negative outstanding is unreachable through
the app.

A debt is **settled** when nothing is outstanding, and **overdue** when its due
date has passed and something still is. Both are derived. A settled debt is
never overdue, and a debt with no due date never is.

### Interest

```
interest = principal × rate / 100 × days / 365
```

- `days` is the whole-day count from `openedAt` to the due date, or to the day
  asked about when the debt has no due date. A negative span projects nothing
  rather than a credit.
- Interest accrues on the original principal, not on what is left. Accruing on a
  shrinking balance would need every payment date weighted separately, which is
  an amortisation schedule wearing a different hat.
- Interest rounds to the đồng with `NSDecimalRound(.plain, scale: 0)`, and all
  date maths use the same fixed Gregorian calendar in `Asia/Ho_Chi_Minh` that
  `SavingsInterest` already pins, so the two sides of the ledger can never round
  a đồng differently.

**Interest is shown, never counted.** It never joins what is outstanding, never
moves an account, and never reaches net worth — exactly as a savings deposit's
projected interest is left out of `AssetSummary.netWorth`, which sums principal.
It is an estimate of what a rate implies, not a đồng anyone has handed over.

Interest actually paid is an ordinary expense transaction, and interest actually
received is ordinary income, recorded on the Spending screen under a category
the owner makes. That is the correct home for it on both counts: unlike the
principal, which only changes where the owner's money sits, interest genuinely
enters or leaves it, and so it belongs in the totals that measure exactly that.

### Cash flow and balances

`CashBalanceSummary.available(...)` becomes:

```
openingBalance
  + net recorded transaction flow
  + net transfer flow
  + net debt flow
  − money funding savings deposits and fund holdings
```

Net debt flow is the signed principal of every debt opened through the account
plus the signed amount of every payment made through it. A debt opening cannot
ride on the funding term the way a savings deposit does: a deposit only ever
removes cash, whereas borrowing adds it, so debt flow needs its own signed term.

`debts` and `payments` have no default value, for the same reason `transactions`
and `transfers` have none, and for one reason worse. A forgotten argument would
silently misreport a spendable balance — and every source-balance guard in the
app now reads that figure, so the app would permit an overdraft while claiming
it had checked.

Net worth becomes:

```
netWorth = total available
         + savings principal
         + fund market value
         + what is outstanding on money lent out
         − what is outstanding on money borrowed
```

Money lent out is counted at what is outstanding, while a savings deposit is
counted at its principal. That is not an inconsistency: a deposit's principal
sits untouched until maturity, whereas the repaid part of a loan has already
landed back in cash and would otherwise be counted twice.

### Allocation and the owed figure

A doughnut cannot draw a negative wedge, so the ring shows what the owner holds
and the amount owed is reported beneath it and subtracted from the total. Money
lent out is an asset — one the owner holds a claim to but cannot spend — so it
becomes a fourth wedge, **Lent out**. Money borrowed is not, so it joins the
overdrawn accounts in the figure beneath.

`AssetAllocation.debt(...)` is renamed **`overdraft(...)`**, keeping its present
meaning, and a new **`liabilities(...)`** adds what is outstanding on borrowed
money to it. Leaving a function named `debt` beside a model named `Debt`, with
the two meaning different things, is a trap worth one rename to close.

```
slices      = positive cash + savings + funds + lent outstanding
liabilities = overdraft + borrowed outstanding

netWorth == total(of: slices) − liabilities
```

The invariant is unchanged in shape and must be proved to hold through
borrowing, lending, and repayment: each moves cash and an outstanding balance by
the same amount in opposite directions, so net worth does not move at all.

Recording an unlinked debt is the one case that does move net worth, and
correctly: stating a previously untracked obligation makes the owner poorer on
paper, because the borrowed money was spent before tracking began.

### Account deletion

An account may only be deleted once nothing points at it. The existing guard
already requires a zero available balance and zero transactions and transfers;
it now also requires zero debts and zero payments. A zero balance no longer
implies debt-freedom — borrowing a sum and repaying it nets to nothing while two
records still name the account, and deleting it would leave them pointing at
nothing. A debt recorded with no account blocks nothing, because it names none.

### Debt deletion

Deleting a debt deletes every payment recorded against it, explicitly, in the
same save. This is a cascade where account deletion is a block, because the
relationship differs in kind: an account outlives the records that name it,
whereas a payment has no meaning at all without its parent and would vanish
silently from every balance. The confirmation says what it costs before the
owner agrees to it.

### Form boundary

`DebtDraft` validates external text before any model is written, in this order,
throwing the first failure:

| Error | Cause |
|---|---|
| `emptyCounterparty` | No name for the other side of the debt |
| `invalidPrincipal` | The principal does not parse as VND |
| `nonPositivePrincipal` | The principal is zero or negative |
| `invalidRate` | A rate was typed and does not parse |
| `rateOutOfRange` | The rate falls outside `0...100` |
| `dueDateBeforeOpening` | The due date is earlier than the opening date |
| `insufficientSourceBalance` | Lending more than the account can hand over |
| `principalBelowPaid` | The edited principal is below what is already paid |

A blank rate means zero. An interest-free loan from a relative is the common
case and should not require a typed nought; only a rate that was typed and
cannot be read is rejected. This is a deliberate divergence from `SavingsDraft`,
where a term deposit paying nothing is nonsense.

`dueDateBeforeOpening` exists because a backwards span projects no interest, and
silently showing nought is worse than saying so.

`principalBelowPaid` applies only when editing. Reducing a principal below what
has been paid would drive the outstanding balance negative, which the derivation
deliberately does not clamp.

The source-balance guard applies to lending only. Borrowing puts money into the
account, so there is nothing to overdraw, and capping it would refuse to borrow
a large sum into a small wallet — the single most common thing this module is
for. The guard is skipped inside the draft rather than merely left uncapped by
the caller, so the rule is testable on its own.

`DebtPaymentDraft` validates in this order:

| Error | Cause |
|---|---|
| `invalidAmount` | The amount does not parse as VND |
| `nonPositiveAmount` | The amount is zero or negative |
| `missingAccount` | No account picked for the money to move through |
| `exceedsOutstanding` | More than is still owed |
| `insufficientSourceBalance` | More than the account can hand over |

Its source-balance guard applies when cash leaves: paying back something
borrowed. Being paid back on something lent is an inflow and is never capped.

When editing, the caller adds the edited record's own contribution back before
either cap is applied, so re-saving an unchanged record is never reported as an
overdraft or an overpayment. This mirrors `TransferDraft`, `SavingsDraft`, and
`FundDraft` — with one difference that has no precedent. A transfer's
contribution to its source account is always negative, so those callers add the
amount back. A debt's contribution is signed and flips with its direction, so
the caller must remove the **signed** principal. Adding it back unconditionally
would over-credit by twice the principal when a debt is flipped from borrowed to
lent, and wave through a loan the account cannot fund.

## UI Contract

- **Debts** opens from the Home toolbar as a sheet, beside **Transfers**, and
  owns its own navigation stack. Two toolbar entry points is the cap: a third
  collapses all of them into a menu rather than crowding the bar.
- The list shows the net position, then **Money I owe**, then **Money owed to
  me**, each with a count. One list rather than a segmented pair, because both
  directions are one record type with identical fields — the shape income and
  expense already share a list in — and because the question the sheet exists to
  answer is the net one, which a picker turns into two taps and a subtraction.
  An empty section is omitted entirely.
- Within a section, unsettled debts come first by due date, undated last, and
  settled debts fall to the bottom carrying a **Settled** chip.
- A card leads with what is outstanding, because the principal is history. It
  reads "Borrowed from *name*" or "Lent to *name*", shows progress towards
  settled as a bar with the same fact written beside it in words, and carries
  the original amount, the rate, the due date, and the projected interest. The
  rate and interest are omitted entirely when no rate was set.
- Borrowed debts take the colour already used for a credit card, which is the
  app's established colour for money owed — a credit card is borrowed money, and
  painting the two differently would be the app disagreeing with itself. Money
  lent out takes one new colour, distinct from spendable cash, term deposits,
  market gains, and bank accounts. **Overdue** and **Settled** are chips carrying
  an icon and a word; neither state is signalled by colour alone.
- Tapping a debt pushes its own screen, rather than opening an editor, because a
  debt is the only record in the app with children and tapping it should show
  them. That screen carries the debt in full, its payments newest first, a
  **Record Payment** button, and **Edit** in the toolbar.
- The debt editor shows a principal card with the direction and amount, a debt
  card with the counterparty, date, and note, a terms card with the rate and an
  optional due date, and a cash account card whose picker offers no account at
  all, with copy explaining that an unlinked debt records the obligation without
  moving money.
- The payment editor shows what is still outstanding, an amount card with a
  one-tap way to settle the balance in full and a live figure for what remains
  after this payment, a cash account card defaulting to the debt's own, and a
  details card.
- Validation errors appear inline beneath the field that caused them.
- On the Home screen the doughnut gains a **Lent out** wedge, the figure beneath
  it keeps the title **Owed** and its existing colour, and its subtitle names
  both sources: borrowed money and overdrawn accounts. The hero card gains an
  **Owed** row, shown only when something is owed.
- Accessibility identifiers: `manage-debts`, `debt-list`, `add-debt`,
  `debt-<id>`, `debt-detail`, `edit-debt`, `add-debt-payment`,
  `debt-payment-<id>`, `debt-direction`, `debt-principal`, `debt-counterparty`,
  `debt-opened-at`, `debt-note`, `debt-rate`, `debt-has-due-date`,
  `debt-due-date`, `debt-account`, `save-debt`, `cancel-debt`, `delete-debt`,
  `confirm-delete-debt`, `debt-payment-amount`,
  `debt-payment-fill-outstanding`, `debt-payment-account`, `debt-payment-date`,
  `debt-payment-note`, `save-debt-payment`, `cancel-debt-payment`,
  `delete-debt-payment`, `confirm-delete-debt-payment`, and the error
  identifiers `debt-principal-error`, `debt-counterparty-error`,
  `debt-rate-error`, `debt-due-date-error`, `debt-account-error`,
  `save-debt-error`, `debt-payment-amount-error`, `debt-payment-account-error`,
  `save-debt-payment-error`.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount`,
  `SavingsDeposit`, `FundHolding`, `TransactionCategory`, `MoneyTransaction`,
  `AccountTransfer`, `Debt`, and `DebtPayment`.
- Lists use SwiftData `@Query`; the editors take `ModelContext` from the
  environment, insert only after validation, and call `save()` explicitly,
  rolling back and surfacing the error when it fails.
- Deleting a debt and its payments happens in one save, so a failure cannot
  orphan a payment.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database.
- Adding two models is an additive schema change; the existing local store opens
  without migration work.

## Testing Strategy

Automated:

- `DebtDraftTests` — every `DebtFormError` case, a blank rate read as nought, a
  rate typed with a comma and one with a dot meaning the same, lending capped at
  the account balance and borrowing never capped, an unlinked debt moving
  nothing, editing through `apply(to:)`, adding a debt's own signed principal
  back when editing, flipping direction in both directions, and a draft round
  trip.
- `DebtPaymentDraftTests` — every `DebtPaymentFormError` case, a payment for
  exactly what is outstanding allowed and one đồng more refused, a payment
  against a settled debt refused, repaying allowed to overdraw a credit card,
  being repaid never capped, both add-backs when editing, and a round trip.
- `DebtSummaryTests` — outstanding in full, reduced, and settled; only a debt's
  own payments counted against it; a payment naming no live debt moving nothing;
  the four signed cases; a debt repaid in full netting to nothing on its
  account; a debt repaid from a different account moving two accounts and
  leaving the pair unchanged; totals per direction; overdue only when past due
  and still owed; and progress guarded against a zero principal.
- `DebtInterestTests` — no rate projecting nothing, a whole year at ten percent
  projecting a tenth, projection to the due date and to the day asked about,
  a passed due date stopping the projection, interest on the original principal
  rather than on what is left, đồng rounding, and a negative span projecting
  nothing.
- `DebtNetWorthTests` — net worth identical before and after borrowing, lending,
  a partial repayment, a full repayment, and being repaid; borrowing into one
  account and repaying from another; projected interest never reaching net
  worth; money lent out drawn as its own wedge; borrowed money never drawn as
  one; a settled debt moving neither the ring nor the owed figure; borrowed
  money and an overdrawn card owed together; the ring total minus liabilities
  equalling net worth; and spendable cash falling by what is lent and rising by
  what is borrowed.
- `DebtPersistenceTests` — field round trip in both directions, with no due date
  and with no account; a stored debt moving the account it names; delete
  restoring the balance; delete removing the payments that belonged to it and
  leaving another debt's alone; a debt staying out of the Spending totals; a
  debt, a transfer, and a transaction stacking on one account; and an account
  named by a debt reporting it against deletion.
- `DebtPaymentPersistenceTests` — field round trip, both directions moving the
  right way, a payment leaving an account other than the one that opened the
  debt, delete restoring both the balance and the outstanding figure, several
  payments settling a debt exactly, editing one down freeing the difference, a
  payment staying out of the Spending totals, and an account named only by a
  payment still reporting it against deletion.
- Existing cash-balance, savings-deposit, fund, income-expense, and transfer
  tests must keep passing, unchanged in value, with the widened balance
  signatures. Any figure that moves means the widening is wrong.

Hands-on, owned by the owner:

- Borrowing a sum into the wallet and watching cash rise, the owed figure rise,
  and total assets hold still.
- Lending a sum from the bank and watching the ring gain a **Lent out** wedge
  with the total unmoved.
- Recording a partial payment, then settling the balance in one tap, and
  watching the card go settled.
- Recording an old debt with no account and watching net worth fall with no
  balance moving.
- A payment larger than the outstanding balance refused, a lent amount larger
  than the account can hand over refused, and the same repayment from a credit
  card allowed.
- Deleting a debt with several payments and watching the balance and the ring
  return to a hand-calculated figure.
- An overdue chip appearing the day after a due date.
- Blocked account deletion while a debt or a payment names the account.
- Relaunch persistence, iPhone Dynamic Type and keyboards, Mac window resizing
  on both the sheet and the pushed screen.

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
- Store amounts positive and let `DebtDirection` carry direction.
- Require a cash account on every payment.
- Delete a debt's payments along with it, in one save.
- Preserve exact `Decimal` values and format VND consistently.
- Pass every "today" in as an argument so no calculation reads the clock.
- Keep both platform builds healthy after every increment.

### Ask first

- Add compound interest, an instalment schedule, or interest split out of a
  payment.
- Let a debt fund a savings deposit or a fund holding.
- Show debts or payments anywhere on the Spending screen.
- Add a fifth wedge to the Home doughnut.
- Add a third entry point to the Home toolbar.
- Rename `SavingsInterest` to something both modules can share.
- Change persisted schema, user flow, copy language, or accessibility
  identifiers.
- Enable iCloud.

### Never do

- Record borrowed or lent money, or a repayment, as an income or an expense.
- Give a debt or a payment a category.
- Let a debt or a payment count towards income, expense, net, or the category
  breakdown.
- Capitalise projected interest onto the outstanding balance, or let projected
  interest move an account.
- Accrue interest on what is left rather than on the original principal.
- Let a payment take a debt past settled. What is outstanding is a floor, not a
  suggestion.
- Store a negative principal or a negative payment amount to mean a direction.
- Represent direction as a `Bool`.
- Copy a debt's direction onto its payments.
- Leave a payment pointing at a deleted debt, or a debt pointing at a deleted
  account.
- Count money lent out as spendable cash.
- Count borrowed cash twice, once where it landed and once as an asset.
- Mutate an account's opening balance to represent a debt or a payment.
- Give `debts` or `payments` a default value on any balance or net-worth
  function.
- Use `Double` or `Float` for money or rates.
- Encode direction, overdue, or settled through colour alone.
- Store a counterparty's account number, card number, or address. A name is the
  whole record the owner needs.

## Success Criteria

- A borrowed debt saves, raises exactly one account's available balance by
  exactly its principal, and leaves net worth identical.
- A lent debt saves, lowers exactly one account's available balance by exactly
  its principal, and leaves net worth identical.
- A debt recorded with no account moves no balance and lowers net worth by
  exactly its principal.
- Every payment moves one account and the outstanding balance by the same
  amount, and leaves net worth identical.
- Projected interest appears on screen and in no total.
- Invalid input does not save and produces a clear inline error, including a
  payment larger than the outstanding balance, a lent amount larger than the
  account can hand over, and a due date before the opening date.
- Editing and deleting a debt or a payment return every balance to a
  hand-calculated figure, and deleting a debt removes its payments.
- The Spending screen's income, expense, net, and category breakdown are
  unchanged by any debt or payment.
- The ring total minus what is owed equals net worth, in every arrangement of
  debts, payments, and overdrawn accounts.
- An account named by a debt or a payment cannot be deleted, and the reason
  names the count.
- Debts and payments survive relaunch on the same device.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

Whether interest paid in cash should stay an ordinary expense transaction under
a category the owner makes, or become a second kind of debt payment. This spec
takes the first, because interest genuinely leaves the owner's money while
principal only changes where it sits — but it means a debt's own screen cannot
show what the debt has cost in interest, only what it is projected to cost, and
that is the sharpest call the module makes.

Otherwise none. Any new requirement moves back through spec approval before
implementation.
