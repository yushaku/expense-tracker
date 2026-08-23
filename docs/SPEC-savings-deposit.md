# Spec: savings-deposit

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `cash-balance`

## Objective

Give the owner the first asset module: record Vietnamese term deposits (sổ tiết
kiệm), see each deposit's maturity date, projected interest, and value at
maturity, and see one total-assets figure that never counts the same đồng twice.

Local storage only. Income and expense transactions, debt, market-priced
investments, iCloud, and MCP stay in their own modules in `CAPABILITY-MAP.md`.

## Scope

### User flow

1. Open the **Savings** tab and see an empty state when no deposit exists.
2. Choose **Add Savings Book**.
3. Enter a name, principal in VND, annual rate in percent, term in months, and
   the opening date; optionally pick a cash or bank account as the funding source.
4. Save and return to the list, which shows maturity date, projected interest,
   and value at maturity per deposit.
5. Tap a deposit to edit every field, or delete it after a confirmation.
6. On the **Cash** tab, see total assets, spendable cash, and total savings; each
   account row shows its available balance and how much of it sits in savings.
7. Relaunch on the same device and see the same deposits.

### Included

- Add, edit, and delete savings deposits.
- Simple interest paid at maturity, computed from principal, rate, and term.
- Optional funding link to one existing cash or bank account.
- One currency: VND.
- Local SwiftData persistence for `SavingsDeposit`.
- Empty, populated, validation-error, and persistence-error states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Interest paid monthly, quarterly, or on any schedule other than at maturity.
- Interest accrued to today, remaining-days countdowns, or maturity reminders.
- Automatic rollover, early withdrawal, partial withdrawal, or closing a deposit
  into a cash account.
- Compound interest, tax withholding, or promotional rate tiers.
- Editing or deleting cash accounts; `SPEC-cash-balance.md` still owns those.
- Multiple currencies, iCloud, market data, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

```swift
@Model
final class SavingsDeposit {
    var id: UUID
    var name: String
    var principal: Decimal
    var annualInterestRate: Decimal   // percent per year, e.g. 5.6
    var termMonths: Int
    var openedAt: Date
    var currencyCode: String
    var createdAt: Date
    var sourceAccountID: UUID?
}
```

Rules:

- `name` is trimmed and must contain at least one non-whitespace character.
- `principal` must parse as a decimal greater than zero.
- `annualInterestRate` must parse and fall in `0...100`. Input accepts `5,6`,
  `5.6`, and a trailing `%`; anything else is rejected.
- `termMonths` must be a whole number in `1...120`.
- `sourceAccountID` is the funding account's `id`, or `nil` when the deposit is
  not funded from a tracked account.
- The first slice always writes `currencyCode = "VND"`.
- `createdAt` is supplied by the caller so tests do not depend on wall-clock time.
- Money and rates use `Decimal`; `Double` and `Float` are forbidden.

### Funding link

The funding link is **derived, never destructive**. `CashAccount.openingBalance`
is never modified:

```swift
CashBalanceSummary.fundedAmount(for:deposits:)   // Σ principal of deposits with this account id
CashBalanceSummary.available(for:deposits:)      // openingBalance − fundedAmount
AssetSummary.netWorth(accounts:deposits:)        // Σ available + Σ principal
```

Deleting a deposit restores the account's available balance with no compensating
write. Money moved from an account into a deposit is counted once in net worth.

The link is a stored `UUID`, not a SwiftData relationship: the model stays flat,
the summaries are pure functions testable without a `ModelContext`, and no
relationship migration is needed for the existing local store. Accounts cannot be
deleted in the current scope, so no dangling-id case exists yet; when deletion
arrives, it must clear or repoint the ids it orphans.

### Interest

```swift
interest = principal × rate / 100 × days / 365
```

- `days` is the whole-day count from `openedAt` to the maturity date.
- The maturity date is `openedAt` plus `termMonths`, clamped by the calendar
  (31 Jan + 1 month = 28 Feb).
- Interest rounds to the đồng with `NSDecimalRound(.plain, scale: 0)`.
- All date maths use a fixed Gregorian calendar in `Asia/Ho_Chi_Minh` so results
  never depend on the machine's locale or time zone.

### Form boundary

```swift
enum SavingsFormError: Error, Equatable {
    case emptyName
    case invalidPrincipal, nonPositivePrincipal
    case invalidRate, rateOutOfRange
    case invalidTerm, termOutOfRange
    case insufficientSourceBalance
}
```

`SavingsDraft.validate(availableSourceBalance:)` returns validated values or a
typed error. When a funding account is selected, the principal must not exceed
its available balance; when editing, the caller adds the deposit's own principal
back first, so re-saving an unchanged amount is never reported as an overdraft.
A persistence failure keeps the form filled and shows a save error.

## UI Contract

- `RootTabView` hosts two tabs: **Cash** (`AccountListView`) and **Savings**
  (`SavingsListView`).
- The Cash tab's hero card shows total assets first, then spendable cash, total
  savings, and the account count. Each account row shows its available balance
  and, when relevant, the amount held in savings.
- The Savings tab shows total principal first, then projected interest and the
  deposit count, then one card per deposit ordered by `createdAt` ascending.
- Each deposit card shows name, funding source, principal, rate, term, maturity
  date, projected interest, and value at maturity.
- Adding and editing use the same sheet; the edit sheet also offers Delete behind
  a confirmation dialog. The list is a card stack, not a `List`, so deletion is a
  button rather than a swipe — this works identically on iPhone and Mac.
- Validation errors appear inline beside the affected field, with icon plus text,
  never color alone.
- New accessibility identifiers: `savings-list`, `add-savings`, `savings-name`,
  `savings-principal`, `savings-rate`, `savings-term`, `savings-opened-at`,
  `savings-source`, `save-savings`, `cancel-savings`, `delete-savings`,
  `confirm-delete-savings`, `cash-tab`, `savings-tab`. Every identifier from
  `SPEC-cash-balance.md` is unchanged.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount` and
  `SavingsDeposit`.
- Lists use SwiftData `@Query`; the editor takes `ModelContext` from the
  environment, inserts only after validation, and calls `save()` explicitly,
  rolling back and surfacing the error when it fails.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database. A test must hold the `ModelContainer` for as long
  as it uses the context: a `ModelContext` does not keep its container alive, and
  a released container leaves the context dangling, which traps inside SwiftData
  on the next insert.
- Adding `SavingsDeposit` is an additive schema change; the existing local store
  opens without migration work.

## Testing Strategy

Automated:

- `SavingsInterestTests` — maturity date including short-month clamping, day
  counts, six- and twelve-month interest, zero-value cases, đồng rounding.
- `PercentInputTests` — comma and dot decimals, trailing `%`, rejected junk.
- `SavingsDraftTests` — every `SavingsFormError` case, the source-balance
  boundary, and a deposit-to-draft round trip.
- `AssetSummaryTests` — principal and interest totals, available balance with one
  and several deposits, and net worth counting funded money exactly once.
- `SavingsDepositPersistenceTests` — field round trip, unlinked deposit, delete
  restoring available balance, and editing through the draft.
- Existing cash-balance tests must keep passing unchanged.

Hands-on, owned by the owner:

- Maturity date and interest against a hand calculation.
- Funding a deposit from an account and watching total assets stay flat.
- Over-funding rejected inline, editing without a false overdraft, deleting to
  restore the balance.
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
- Preserve exact `Decimal` values and format VND consistently.
- Keep both platform builds healthy after every increment.

### Ask first

- Add interest schedules, rollover, early withdrawal, or maturity notifications.
- Add editing or deletion of cash accounts.
- Change persisted schema, user flow, copy language, or accessibility identifiers.
- Enable iCloud.

### Never do

- Store bank credentials, account numbers, or secrets.
- Use `Double` or `Float` for money or rates.
- Mutate an account's opening balance to represent a transfer.
- Encode financial state only through color.

## Success Criteria

- A valid deposit saves and shows a maturity date and interest matching a hand
  calculation.
- Invalid input does not save and produces a clear inline error.
- Funding a deposit from an account lowers that account's available balance by
  exactly the principal and leaves total assets unchanged.
- Editing a deposit without changing the principal never reports an overdraft.
- Deleting a deposit restores the funding account's available balance.
- Deposits survive relaunch on the same device.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

None. Any new requirement moves back through spec approval before implementation.
