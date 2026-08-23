# Spec: fund-etf-holdings

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `cash-balance`, `savings-deposit`

## Objective

Give the owner a third asset class: fund certificates (chứng chỉ quỹ) and ETFs.
Record how many units are held, what they cost on average, and the latest NAV or
market price per unit, then see cost basis, market value, and unrealized profit
or loss per holding and in total — folded into the same total-assets figure
without counting a single đồng twice.

Local storage only, NAV entered by hand. Individual buy and sell trades, realized
profit and loss, automatic price refresh, iCloud, and MCP stay in their own
modules in `CAPABILITY-MAP.md`.

## Scope

### User flow

1. Open the **Funds** tab and see an empty state when no holding exists.
2. Choose **Add Holding**.
3. Enter a name, a ticker symbol, the kind (Fund or ETF), the number of units,
   the average cost per unit, the current NAV per unit and the date that NAV is
   from; optionally pick a cash or bank account as the funding source.
4. Save and return to the list, which shows cost basis, market value, and
   unrealized profit or loss per holding.
5. Tap a holding to edit every field, or delete it after a confirmation.
6. On the **Cash** tab, see total assets include the holdings' market value, and
   each account row show how much of it sits in funds.
7. Relaunch on the same device and see the same holdings.

### Included

- Add, edit, and delete fund and ETF holdings.
- Fractional unit counts.
- Cost basis, market value, unrealized profit/loss, and return percent.
- A hand-entered NAV per unit with the date it is from.
- Optional funding link to one existing cash or bank account, deducting the
  holding's cost basis from that account's available balance.
- One currency: VND.
- Local SwiftData persistence for `FundHolding`.
- Empty, populated, validation-error, and persistence-error states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Individual buy/sell trades, lots, FIFO cost basis, or realized profit and loss.
- Automatic NAV or price refresh, network access of any kind, and price history.
- Dividends, distributions, stock splits, fees, or tax.
- Selling a holding back into a cash account.
- Allocation charts or performance over time.
- Editing or deleting cash accounts; `SPEC-cash-balance.md` still owns those.
- Multiple currencies, iCloud, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

```swift
@Model
final class FundHolding {
    var id: UUID
    var name: String
    var symbol: String                  // uppercased ticker, e.g. "FUEVFVND"
    var kind: FundHoldingKind           // .fund | .etf
    var units: Decimal                  // fractional
    var averageCostPerUnit: Decimal
    var currentNAVPerUnit: Decimal
    var navAsOf: Date
    var currencyCode: String
    var createdAt: Date
    var sourceAccountID: UUID?
}
```

Rules:

- `name` is trimmed and must contain at least one non-whitespace character.
- `symbol` is trimmed, uppercased, and must contain at least one non-whitespace
  character.
- `units` must parse as a decimal greater than zero. Input accepts `1234,56`,
  `1234.56`, and grouped digits; anything else is rejected.
- `averageCostPerUnit` and `currentNAVPerUnit` must parse as decimals greater
  than zero.
- `sourceAccountID` is the funding account's `id`, or `nil` when the holding is
  not funded from a tracked account.
- `kind` persists its `String` raw value; a raw value is never renamed.
- The first slice always writes `currencyCode = "VND"`.
- `createdAt` is supplied by the caller so tests do not depend on wall-clock time.
- Money, units, and rates use `Decimal`; `Double` and `Float` are forbidden.

### Valuation

```swift
costBasis            = round(units × averageCostPerUnit)
marketValue          = round(units × currentNAVPerUnit)
unrealizedProfitLoss = marketValue − costBasis
returnPercent        = costBasis > 0 ? (unrealizedProfitLoss / costBasis) × 100 : 0
```

- Money rounds to the đồng with `NSDecimalRound(.plain, scale: 0)`, matching
  `SavingsInterest`.
- `costBasis` is rounded because it is the amount deducted from the funding
  account: the cash side must stay whole-đồng.
- All valuation lives in `FundValuation` as pure static functions; nothing in it
  needs a `ModelContext`, a network, a locale, or a clock.

### Funding link

The funding link is **derived, never destructive**, exactly as in
`SPEC-savings-deposit.md`. `CashAccount.openingBalance` is never modified:

```swift
CashBalanceSummary.fundedAmount(for:deposits:holdings:)
  // Σ deposit principal + Σ holding cost basis for this account id
CashBalanceSummary.available(for:deposits:holdings:)
  // openingBalance − fundedAmount
AssetSummary.netWorth(accounts:deposits:holdings:)
  // Σ available + Σ deposit principal + Σ holding market value
```

Cost basis leaves the cash side and market value enters the asset side, so the
invested đồng is counted exactly once and an unrealized gain shows up as growth
in net worth. Deleting a holding restores the account's available balance with no
compensating write.

`holdings` is an explicit parameter with no default value: a defaulted parameter
would silently overstate available cash at any call site that forgot it.

The link is a stored `UUID`, not a SwiftData relationship, for the reasons given
in `SPEC-savings-deposit.md`. Accounts cannot be deleted in the current scope, so
no dangling-id case exists yet.

### Form boundary

```swift
enum FundFormError: Error, Equatable {
    case emptyName
    case emptySymbol
    case invalidUnits, nonPositiveUnits
    case invalidAverageCost, nonPositiveAverageCost
    case invalidNAV, nonPositiveNAV
    case insufficientSourceBalance
}
```

`FundDraft.validate(availableSourceBalance:)` returns validated values or a typed
error. When a funding account is selected, the holding's **cost basis** must not
exceed its available balance; when editing, the caller adds the holding's own
current cost basis back first, so re-saving unchanged values is never reported as
an overdraft. A persistence failure keeps the form filled and shows a save error.

## UI Contract

- `RootTabView` hosts three tabs: **Cash** (`AccountListView`), **Savings**
  (`SavingsListView`), and **Funds** (`FundListView`).
- The Cash tab's hero card shows total assets first, then spendable cash, total
  savings, total funds at market value, and the account count. Each account row
  shows its available balance and, when relevant, the amounts held in savings and
  in funds.
- The Funds tab shows total market value first, then cost basis, unrealized
  profit or loss, and the holding count, then one card per holding ordered by
  `createdAt` ascending.
- Each holding card shows name, symbol, kind, funding source, units, average
  cost, NAV with its as-of date, cost basis, market value, and profit or loss.
- Profit and loss is **never encoded by colour alone**: an arrow symbol and an
  explicit `+` or `−` sign carry the meaning, with colour as reinforcement.
- Adding and editing use the same sheet; the edit sheet also offers Delete behind
  a confirmation dialog. The list is a card stack, not a `List`, so deletion is a
  button rather than a swipe — this works identically on iPhone and Mac.
- Validation errors appear inline beside the affected field, with icon plus text,
  never colour alone.
- New accessibility identifiers: `funds-list`, `add-fund`, `fund-name`,
  `fund-symbol`, `fund-kind`, `fund-units`, `fund-average-cost`, `fund-nav`,
  `fund-nav-date`, `fund-source`, `save-fund`, `cancel-fund`, `delete-fund`,
  `confirm-delete-fund`, `funds-tab`. Every identifier from
  `SPEC-cash-balance.md` and `SPEC-savings-deposit.md` is unchanged.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount`,
  `SavingsDeposit`, and `FundHolding`.
- Lists use SwiftData `@Query`; the editor takes `ModelContext` from the
  environment, inserts only after validation, and calls `save()` explicitly,
  rolling back and surfacing the error when it fails.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database. A test must hold the `ModelContainer` for as long
  as it uses the context.
- Adding `FundHolding` is an additive schema change; the existing local store
  opens without migration work.

## Testing Strategy

Automated:

- `UnitQuantityTests` — comma and dot decimals, grouped digits, rejected junk,
  and a format/parse round trip.
- `FundValuationTests` — cost basis and market value including đồng rounding on
  fractional units, gain and loss cases, and the zero-cost-basis guard on
  `returnPercent`.
- `FundDraftTests` — every `FundFormError` case, the cost-basis-versus-balance
  boundary, editing without a false overdraft, and a holding-to-draft round trip.
- `FundSummaryTests` — totals across several holdings.
- `FundHoldingPersistenceTests` — field round trip, unlinked holding, delete
  restoring available balance, and editing through the draft.
- `CashBalanceSummaryTests` and `AssetSummaryTests` gain cases where one account
  funds both a savings deposit and a fund holding.
- Existing cash-balance and savings-deposit tests must keep passing.

Hands-on, owned by the owner:

- Funding a holding from an account and watching total assets stay flat while
  NAV equals average cost.
- Raising and lowering the NAV and reading the profit or loss with colour ignored.
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
- Deduct cost basis from cash and add market value to assets, never both.
- Preserve exact `Decimal` values and format VND consistently.
- Keep both platform builds healthy after every increment.

### Ask first

- Add trades, lots, realized profit and loss, dividends, or splits.
- Fetch prices over the network or add a market-data provider.
- Add selling a holding back into a cash account.
- Change persisted schema, user flow, copy language, or accessibility identifiers.
- Enable iCloud.

### Never do

- Store brokerage credentials, account numbers, or secrets.
- Use `Double` or `Float` for money, units, or rates.
- Mutate an account's opening balance to represent a purchase.
- Count the same đồng in both available cash and market value.
- Encode financial state only through colour.

## Success Criteria

- A valid holding saves and shows a cost basis and market value matching a hand
  calculation.
- Invalid input does not save and produces a clear inline error.
- Funding a holding from an account lowers that account's available balance by
  exactly the cost basis and leaves total assets unchanged while NAV equals
  average cost.
- Raising the NAV raises total assets by exactly the unrealized gain.
- Editing a holding without changing units or cost never reports an overdraft.
- Deleting a holding restores the funding account's available balance.
- Holdings survive relaunch on the same device.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

None. Any new requirement moves back through spec approval before implementation.
