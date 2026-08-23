# Spec: income-expense

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `cash-balance`

## Objective

Let the owner record money coming in and money going out, each against one cash
account, and see every account balance move accordingly. Today `openingBalance`
is a hand-entered figure that only ever shrinks by what moved into savings or
funds, so the app drifts away from reality until the owner rewrites the number by
hand. After this module, `openingBalance` means "balance when tracking started"
and the running balance is derived from it plus recorded cash flow.

Transactions are grouped by category. Categories are the owner's own records —
created, renamed, restyled, and deleted from inside the app — with a starter set
seeded on an empty store.

Transfers between two accounts, budgets, recurring entries, attachments, and
reporting beyond a monthly total stay in later modules.

## Scope

### User flow

1. Open the **Spending** tab and see the current month with an empty state when
   no transaction exists.
2. Choose **Add Transaction**.
3. Pick income or expense, enter an amount, pick a category and an account,
   choose the date, and optionally write a note.
4. Save and return to the list, which shows the month's total income, total
   expense, and net, then one card per transaction, newest first.
5. Step to the previous or next month and see that month's totals and entries.
6. Tap a transaction to edit every field, or delete it after a confirmation.
7. Open **Categories** from the toolbar to add, edit, or delete a category.
   Deleting a category that is in use first asks which category its transactions
   move to.
8. On the **Home** tab, see each account's available balance already reflect the
   recorded flow, and total assets move with it.
9. Relaunch on the same device and see the same transactions and categories.

### Included

- Add, edit, and delete income and expense transactions.
- A required link to exactly one existing cash, bank, or credit account.
- Owner-managed categories with a name, a kind, an SF Symbol, and a colour.
- A seeded starter set of categories on an empty store.
- Reassign-then-delete for a category that transactions still reference.
- Month-scoped list and totals with backward and forward navigation.
- Account available balance and total assets derived from recorded flow.
- One currency: VND.
- Local SwiftData persistence for `MoneyTransaction` and `TransactionCategory`.
- Empty, populated, validation-error, and persistence-error states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Transfers between two accounts; a later module owns them.
- Budgets, spending limits, and alerts.
- Recurring or scheduled transactions, and splitting one transaction across
  categories.
- Receipts, attachments, tags, merchants, and geolocation.
- Charts, category breakdowns, and any period other than a calendar month.
- Import from a bank, CSV, or any network access.
- Multiple currencies, iCloud, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

```swift
enum TransactionKind: String, Codable, CaseIterable {
    case income
    case expense
}

@Model
final class TransactionCategory {
    var id: UUID
    var name: String
    var kind: TransactionKind
    var symbolName: String              // whitelisted SF Symbol
    var colorName: String               // whitelisted palette entry
    var createdAt: Date
}

@Model
final class MoneyTransaction {
    var id: UUID
    var kind: TransactionKind
    var amount: Decimal                 // always positive; kind carries direction
    var occurredAt: Date
    var note: String
    var accountID: UUID                 // required
    var categoryID: UUID?
    var currencyCode: String
    var createdAt: Date
}
```

Rules:

- `amount` is stored positive and must parse as a decimal greater than zero.
  Direction lives in `kind` alone, so no call site has to agree on a sign
  convention.
- `accountID` is **not** optional, unlike `sourceAccountID` on `SavingsDeposit`
  and `FundHolding`. A transaction with no account cannot move a balance, which
  is this module's only purpose. The form therefore requires an account, and the
  empty state points the owner at the Home tab when none exists.
- `categoryID` is optional so a transaction survives a category deletion that
  went wrong halfway; the UI never writes `nil` on the happy path and renders a
  missing category as "Uncategorized".
- `note` is trimmed and may be empty.
- `name` on a category is trimmed and must contain at least one non-whitespace
  character. Two categories may not share a name within the same `kind`.
- `symbolName` and `colorName` are only ever written from `CategoryPalette`, so
  renaming a theme colour cannot leave an unrenderable record behind.
- `kind` persists its `String` raw value; a raw value is never renamed.
- The first slice always writes `currencyCode = "VND"`.
- `createdAt` is supplied by the caller so tests do not depend on wall-clock time.
- Money uses `Decimal`; `Double` and `Float` are forbidden.

### Cash flow and balances

`CashAccount.openingBalance` is still **never** modified. The derived balance
gains one term:

```swift
TransactionSummary.netFlow(for:transactions:)
  // Σ income amount − Σ expense amount for this account id

CashBalanceSummary.available(for:deposits:holdings:transactions:)
  // openingBalance + netFlow − fundedAmount

AssetSummary.netWorth(accounts:deposits:holdings:transactions:)
  // Σ available + Σ deposit principal + Σ holding market value
```

`transactions` is an explicit parameter with no default value, for the same
reason `holdings` has none in `SPEC-fund-etf-holdings.md`: a defaulted parameter
would silently misreport a balance at any call site that forgot it.

Balances are all-time, not month-scoped. Only the list and its totals are scoped
to the visible month, so stepping back a month never changes an account balance.

Recording an expense lowers available cash and therefore total assets; recording
income raises both. Nothing is double counted, because a transaction contributes
to exactly one account's netFlow and to no other total.

An expense is allowed to drive a balance negative. Cash and bank accounts can go
overdrawn on paper, and a credit account is expected to. This module adds no
overdraft rule of its own; the savings and fund overdraft checks are unchanged
and now read the flow-adjusted available balance.

### Account deletion

`cash-balance` allows deleting an account only when its available balance is
zero. That test alone is no longer sufficient: an account with 100 in and 100 out
sits at zero while still owning two transactions, and deleting it would orphan
them. Deletion now also requires that no transaction reference the account, and
the blocked reason names the count.

### Months

`TransactionPeriod` is a pure static namespace over `SavingsInterest.calendar`
(Gregorian, `Asia/Ho_Chi_Minh`), reused rather than redefined so no module reads
the machine locale:

```swift
TransactionPeriod.startOfMonth(for: Date) -> Date
TransactionPeriod.endOfMonth(for: Date) -> Date      // exclusive upper bound
TransactionPeriod.shift(_ date: Date, byMonths: Int) -> Date
TransactionPeriod.contains(_ date: Date, monthOf: Date) -> Bool
TransactionPeriod.title(for: Date) -> String         // e.g. "August 2026"
```

Every function takes the dates it needs; nothing reads the clock, so tests are
deterministic.

### Form boundary

```swift
enum TransactionFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case missingCategory
}

enum CategoryFormError: Error, Equatable {
    case emptyName
    case duplicateName
}
```

`TransactionDraft.validate(...)` and `CategoryDraft.validate(...)` return
validated values or a typed error, matching `FundDraft` and `SavingsDraft`. A
persistence failure keeps the form filled and shows a save error.

Deleting a category that transactions reference is a two-step flow: the editor
opens a reassign sheet listing the other categories of the same kind, the owner
picks one, and the app rewrites every affected `categoryID` and deletes the old
category inside a single `save()`, rolling back on failure. Cancelling changes
nothing. A category with no transactions deletes behind a plain confirmation.

## UI Contract

- `RootTabView` hosts four tabs: **Home**, **Savings**, **Funds**, and
  **Spending** (`TransactionListView`).
- The Spending tab shows a month header with previous and next buttons, then a
  hero card with net first, then income and expense and the transaction count,
  then one card per transaction ordered by `occurredAt` descending.
- Each transaction card shows the category icon and colour, the category name,
  the note when present, the account name, the date, and the amount.
- Direction is **never encoded by colour alone**: an explicit `+` or `−` sign and
  an arrow symbol carry the meaning, with colour as reinforcement.
- The toolbar carries Add Transaction and a Categories button opening
  `CategoryListView` as a sheet; there is no fifth tab.
- `CategoryListView` groups categories under Income and Expense headings, each
  row opening the category editor.
- Adding and editing use the same sheet in both flows; the edit sheet also offers
  Delete behind a confirmation dialog. Lists are card stacks, not `List`, so
  deletion is a button rather than a swipe — identical on iPhone and Mac.
- Validation errors appear inline beside the affected field, with icon plus text,
  never colour alone.
- The Home tab's account rows and hero card are unchanged in layout; their
  numbers now include recorded flow.
- Below the hero card, the Home tab shows an assets doughnut split into cash,
  savings, and funds — the three groups `AssetSummary.netWorth` adds up — with a
  legend naming each group, its amount, and its share. A doughnut cannot draw a
  negative wedge and drawing one by magnitude would make debt look like an
  asset, so overdrawn accounts stay out of the ring and are reported beneath it
  as an amount owed. `ring total − owed == net worth`. The card is hidden when
  there is nothing to show. Every wedge carries a symbol as well as a colour,
  and the legend states each figure in text.
- New accessibility identifiers: `spending-tab`, `spending-list`,
  `previous-month`, `next-month`, `add-transaction`, `transaction-kind`,
  `transaction-amount`, `transaction-category`, `transaction-account`,
  `transaction-date`, `transaction-note`, `save-transaction`,
  `cancel-transaction`, `delete-transaction`, `confirm-delete-transaction`,
  `manage-categories`, `category-list`, `add-category`, `category-name`,
  `category-kind`, `category-symbol`, `category-color`, `save-category`,
  `cancel-category`, `delete-category`, `confirm-delete-category`,
  `reassign-category`, `confirm-reassign-category`.
- The accounts tab is renamed from Cash to **Home**, taking a house symbol and
  the title "Home", and its identifier changes from `cash-tab` to `home-tab`.
  This is the only identifier from the three earlier specs that changes; the
  rest are unchanged. `SPEC-savings-deposit.md` still lists the old name.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount`,
  `SavingsDeposit`, `FundHolding`, `TransactionCategory`, and `MoneyTransaction`.
- The starter categories are seeded once, guarded by a count query, so a second
  launch never duplicates them and a deliberately emptied category list stays
  empty only until the app finds zero categories again — the guard is
  "no categories at all", which the owner reaches only by deleting every one.
- Lists use SwiftData `@Query`; editors take `ModelContext` from the environment,
  insert only after validation, and call `save()` explicitly, rolling back and
  surfacing the error when it fails.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database. A test must hold the `ModelContainer` for as long
  as it uses the context.
- Adding the two models is an additive schema change; the existing local store
  opens without migration work.

## Testing Strategy

Automated:

- `TransactionPeriodTests` — month boundaries, an exclusive upper bound, stepping
  across a year boundary, and membership at the first and last instant.
- `TransactionSummaryTests` — income, expense, and net totals; netFlow per
  account; an account with no transactions; month filtering.
- `TransactionDraftTests` — every `TransactionFormError` case, a transaction to
  draft round trip, and editing through `apply(to:)`.
- `CategoryDraftTests` — empty name, duplicate name within a kind, the same name
  allowed across kinds, and a round trip.
- `MoneyTransactionPersistenceTests` — field round trip, edit through the draft,
  and delete.
- `TransactionCategoryPersistenceTests` — seeding once, not reseeding on a
  populated store, and reassign-then-delete moving every affected transaction.
- `CashBalanceSummaryTests` and `AssetSummaryTests` gain cases where one account
  carries transactions and funds both a savings deposit and a fund holding, and
  a case where flow drives a balance negative.
- Existing cash-balance, savings-deposit, and fund tests must keep passing.

Hands-on, owned by the owner:

- Recording an expense and watching one account's available balance and total
  assets fall by exactly that amount.
- Editing and deleting a transaction and watching the balance return.
- Stepping months and confirming balances do not move with the view.
- Deleting a category in use through the reassign flow, and cancelling it.
- Blocked account deletion while transactions remain.
- Relaunch persistence, iPhone Dynamic Type and keyboards, Mac window resizing.

No automated test may depend on network access, iCloud, current locale,
wall-clock time, or the owner's real app database.

## Verification Commands

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
rtk swift format lint --strict --recursive MonMon MonMonTests
```

## Boundaries

### Always do

- Validate input before inserting or mutating a SwiftData model.
- Keep `openingBalance` untouched; derive available balances instead.
- Store `amount` positive and let `kind` carry direction.
- Require an account on every transaction.
- Reassign before deleting a category that transactions reference.
- Preserve exact `Decimal` values and format VND consistently.
- Keep both platform builds healthy after every increment.

### Ask first

- Add transfers between accounts, budgets, or recurring transactions.
- Split one transaction across several categories.
- Add charts or any period other than a calendar month.
- Change persisted schema, user flow, copy language, or accessibility identifiers.
- Enable iCloud or add a third-party dependency.

### Never do

- Store bank credentials, card numbers, or secrets.
- Use `Double` or `Float` for money.
- Mutate an account's opening balance to represent a transaction.
- Write a negative `amount` to represent an expense.
- Leave a transaction pointing at a deleted account.
- Encode financial direction only through colour.

## Success Criteria

- A valid transaction saves and moves exactly one account's available balance by
  exactly its amount, in the direction its kind implies.
- Invalid input does not save and produces a clear inline error.
- Editing and deleting a transaction return the balance to a hand-calculated
  figure.
- Month navigation changes the list and its totals and never changes a balance.
- Deleting a category in use moves every one of its transactions to the chosen
  replacement, and cancelling leaves both the category and the transactions
  untouched.
- An account with transactions cannot be deleted, and the reason names the count.
- The starter categories appear once on an empty store and never duplicate.
- Transactions and categories survive relaunch on the same device.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

None. Any new requirement moves back through spec approval before implementation.
