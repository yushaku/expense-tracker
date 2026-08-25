# MonMon

MonMon is a private personal-finance app for iPhone and Mac, themed with
Catppuccin — Latte in light, Frappé in dark. It has nine slices today.
`cash-balance` lets one owner add, edit, and delete local cash, bank, and credit
card accounts with a VND opening balance. `savings-deposit` adds term
deposits (sổ tiết kiệm) with maturity dates, projected interest, and an optional
funding account, plus a total-assets figure that counts transferred money only
once. `fund-etf-holdings` adds fund certificates (chứng chỉ quỹ) and ETFs held in
units, valued at a hand-entered NAV, showing cost basis, market value, and
unrealized profit or loss. `income-expense` records money in and out against one
account each, grouped by categories the owner manages, so every balance follows
what was recorded rather than a hand-edited number. `account-transfer` moves
money between two of the owner's own accounts, so both balances follow and total
assets stay put. `debt-tracking` records money borrowed and money lent out, with
the payments against them: the account moves by exactly the principal, what is
outstanding follows the payments, and total assets stay put through all of it.
`market-valuation` replaces the hand-typed NAV with one fetched from Fmarket for
open-ended funds and VNDIRECT for listed ETFs, and values physical gold from the
shop-buy side of a vang.today quote. The price lives on a `FundInstrument`
catalogue so one catalogue code can only ever carry one price. Every fetch is
owner-triggered. `recurring-transactions` records money that comes back — rent,
salary, a subscription — from a rule the owner writes once, catching up on
every date it has fallen due each time the app is opened.

## Requirements

- macOS 15 or newer
- Xcode 26.6 or compatible newer version
- Swift 6
- iOS 18 or newer for an iPhone Simulator or physical iPhone

## Open the project

```sh
rtk open MonMon.xcodeproj
```

Use the shared `MonMon` scheme in Xcode.

## Build flavours

The build configuration picks the flavour, and the flavour owns every identifier
that decides where data lives. A dev install and a prod install on the same phone
share nothing.

| | Dev (`Debug`) | Prod (`Release`) |
| --- | --- | --- |
| Home screen name | MonMon Dev | MonMon |
| Bundle identifier | `com.sonlv.monmon.local.yushaku` | `com.sonlv.monmon.app` |
| App group | `group.com.sonlv.monmon.local.yushaku` | `group.com.sonlv.monmon.app` |
| CloudKit container | `iCloud.monmon.dev` | `iCloud.monmon` |
| Push environment | `development` | `development` (see `APS_ENVIRONMENT` in `Config/Release.xcconfig`) |

Those values are set in `Config/Debug.xcconfig` and `Config/Release.xcconfig`.
Everything downstream reads them: `PRODUCT_BUNDLE_IDENTIFIER` in the project, the
two `.entitlements` files, and the `Info.plist` keys `MonMonAppGroupIdentifier`
and `MonMonCloudKitContainer` that `ShareViewController` and `CloudSync` read at
runtime. Nothing hard-codes an identifier in Swift, so adding a flavour is an
xcconfig change.

A distinct bundle identifier gives each flavour its own container, which is what
separates the SwiftData store and `UserDefaults`; the app group separates the
share extension's statement inbox; the CloudKit container separates what syncs.

Build and install the dev flavour on the phone:

```sh
scripts/run-iphone.sh Yushaku
```

Build the prod flavour. The script refuses to run unless `HEAD` is a clean `main`
matching `origin/main`, archives with the `Release` configuration, and exports an
`.ipa` into `build/prod`. Pass a device name to also install and launch it:

```sh
scripts/build-prod.sh
scripts/build-prod.sh Yushaku
```

Both flavours need their App ID, app group, and CloudKit container to exist in
the developer account before signing succeeds. Xcode registers them when you add
the capability under **Signing & Capabilities** with that configuration selected;
`xcodebuild` will not create a CloudKit container on its own.

## Build

Build the native Mac app:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
```

Build against the iPhone Simulator SDK without requiring an installed runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

## Test and format

Run the macOS unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

## Run on Mac

1. Open `MonMon.xcodeproj`.
2. Select the `MonMon` scheme.
3. Select **My Mac** as the destination.
4. Press **Command-R**.

No signing team is required for the current local Mac build.

## Run on iPhone Simulator

1. In Xcode, open **Settings > Components** and install an iOS Simulator runtime
   if no iPhone destination is available.
2. Select the `MonMon` scheme and an installed iPhone Simulator.
3. Press **Command-R**.

The Simulator runtime is only needed to launch the app. The command-line SDK build
above can compile the iOS target without it.

## Run on a physical iPhone

1. Sign in under **Xcode > Settings > Accounts**.
2. Select the `MonMon` target, open **Signing & Capabilities**, and choose your
   development team.
3. Connect and trust the iPhone, enable Developer Mode when prompted, and select
   the phone as the run destination.
4. Press **Command-R**.

Signing identities, provisioning profiles, and Xcode user state must remain local
and are excluded by `.gitignore`.

## Current scope

- Included: add, edit, and delete cash, bank, and credit card accounts; add,
  edit, and delete savings deposits with simple interest paid at maturity; add,
  edit, and delete fund, ETF, and physical-gold holdings, each held in a
  catalogue instrument that owns its price, under one Investments tab that
  totals them together; enter gold weight in chỉ while storing lượng; value
  gold at the shop's buy price while showing its buy/sell spread; sell part or
  all of a position into a chosen cash account, which settles its profit as
  realized without ever rewriting the lot it came out of; record
  income and expenses against one account each under owner-managed categories,
  browsed a day, a month, a year, or a hand-picked range at a time; add, edit,
  and delete transfers between two accounts, opened from the Home toolbar; an
  optional funding link that lowers an account's available balance without
  touching its opening balance; add, edit, and delete debts in both directions
  with their payments, opened from the Home toolbar, with an optional cash
  account, an optional rate and due date, and projected interest that is shown
  but never counted; VND validation and formatting, exact `Decimal` totals,
  private iCloud-backed SwiftData persistence, and shared SwiftUI UI.
- Owner validation: form behavior, interest and valuation against a hand
  calculation, relaunch persistence, iPhone Dynamic Type and keyboard, and Mac
  window resizing.
- Recurring: rules for money that comes back — rent, salary, a subscription —
  each repeating daily, weekly, monthly, or yearly at an interval the owner
  picks, from a start date, optionally until an end date, and pausable without
  being deleted. A rule holds no money: opening the app records every date it
  has fallen due since it was last caught up, as ordinary transactions carrying
  the rule's id, so balances and totals follow with no compensating write. A
  start date in the past backfills what it already covered, capped at 400
  entries per save. One rule can only ever record one entry per day, enforced
  before the write and folded afterwards, so two devices cannot record the same
  month's rent twice. Editing a rule changes only what it records next, and
  deleting one keeps everything it already recorded.
- Month rail: the run of months pinned under the Spending navigation bar, the
  one on show marked and scrolled to the middle, so stepping a month is one tap
  from anywhere on the screen. The bar's calendar button still opens the fuller
  picker behind it — a day, a month, a year, or a hand-picked span.
- Spending calendar: a month grid below the category breakdown, each day
  carrying what it took in and what it paid out, so a heavy day is visible
  without opening anything. Days either side of the month are drawn faintly
  rather than blanked, so every row is a whole week. Its arrows re-cut the
  period the whole screen is showing, so the totals above it never describe a
  month the grid is not. Tapping a day opens that day on its own, with its
  income, expense, and net, the entries behind them, and an add button that
  starts a new entry on that day.
- Spending setup: one row of buttons above the category breakdown opens the
  categories, the recurring rules, and the defaults a new entry starts on — the
  account, the expense category, and the income category. Switching an entry
  between income and expense picks up that direction's own default instead of
  emptying the field. The defaults live here rather than on the Settings tab,
  beside the entries they shape.
- Settings: a light/dark/system theme, and an optional Face ID, Touch ID, or
  passcode lock that hides the screen on launch and after a minute away. The
  lock is a gate on the screen, not encryption; the records on disk are
  protected by the operating system's file protection and nothing more.
- Backup: a switch for mirroring every record through the owner's own private
  iCloud database, and a "Sync now" button that flushes pending edits, checks
  the account, and reports what the store says next. SwiftData fixes a store's
  mirroring when the container is built, so the switch takes effect on the next
  launch and says so on screen. No call forces a push, so the button never
  claims one happened; when nothing is reported back it says the changes stay
  queued.
- Market data: a fund, ETF, and gold catalogue with one price per code,
  refreshed when the owner asks and never on a timer, on launch, or in the
  background.
  Fmarket supplies open-ended fund NAV, VNDIRECT supplies listed ETF closes, and
  vang.today supplies VND gold shop-buy and shop-sell quotes per lượng. The
  Fmarket and vang.today catalogues can be imported and searched, grouped by
  provider owner or brand. A stale price is marked in words, not by colour
  alone. A fetch that fails leaves the previous price standing and says why.
  Only a ticker or gold type code ever leaves the device — never a balance, a
  unit count, an account name, or anything identifying the owner.
- Not included yet: budgets, interest paid on a schedule, rollover or early
  withdrawal, compound interest or amortisation schedules on a debt, price
  history or charts, a market-holiday calendar, AI, or MCP.
- Not included, and not planned: individual buy/sell trades and equity or
  crypto positions. Closing a position is recorded, so realized profit and loss
  is too — but only against the lot the units left, which is a way out of a
  holding rather than a trade ledger.

## Architecture

- One multiplatform app target shares SwiftUI source between iOS and macOS.
- One dependency: [MijickCalendarView](https://github.com/Mijick/CalendarView)
  (MIT), which draws the calendar inside `DateField`. It is plain SwiftUI on
  both platforms and touches nothing but the view it is asked to draw. The
  resolved version is pinned in `Package.resolved`.
- SwiftData stores `CashAccount`, `SavingsDeposit`, `FundInstrument`,
  `FundHolding`, `FundSale`, `TransactionCategory`, `MoneyTransaction`,
  `AccountTransfer`, `Debt`, `DebtPayment`, and `RecurringRule` records
  in the owner's private iCloud database; `@Query` drives every visible list
  and combined total.
- Nothing stores a balance. Every account balance, every total, and net worth
  itself is computed from the records each time, and `openingBalance` is never
  rewritten. That is what lets a record be deleted with no compensating write.
- `AccountDraft`, `SavingsDraft`, `FundDraft`, `FundSaleDraft`,
  `TransactionDraft`, `CategoryDraft`, `TransferDraft`, `DebtDraft`,
  `DebtPaymentDraft`, and `RecurringRuleDraft` validate
  external text before any model is inserted or mutated, and money uses
  `Decimal` throughout.
- A savings deposit and a fund holding each store their funding account's `id`;
  available balances and total assets are derived, so deleting one needs no
  compensating write.
- A holding's cost basis leaves the cash side while its market value enters the
  asset side, so invested money is counted once and a gain shows as growth.
- A sale is its own record and never shrinks the lot it came out of. The lot
  keeps its original cost subtracted from the cash side, because that is the
  money that left on the day it was bought; the sale adds its proceeds back, and
  only the units still held carry a market value. At the moment of a sale those
  three cancel, so net worth does not move — the gain stops being unrealized and
  starts being cash. It also means a past month can still be reconstructed with
  the position open, which shrinking the lot would have made impossible.
- A transaction stores a positive amount and carries its direction in `kind`, so
  no call site has to agree on a sign convention. An account's available balance
  is its opening balance plus recorded flow minus what it funds; the opening
  balance itself is never rewritten.
- A transfer stores a positive amount too, and the pair of accounts it names
  carries the direction. It is neither income nor an expense, so it never
  reaches the Spending totals, and because one account's outflow is another's
  inflow it leaves total assets untouched.
- A debt stores a positive principal and carries its direction in an enum, and
  its payments read that direction from the debt rather than repeating it. Debt
  flow does not cancel out the way transfer flow does, because the counterparty
  lives outside the app — so net worth adds what is still owed to the owner and
  subtracts what the owner still owes, and borrowing, lending, and repaying all
  leave it exactly where it was. Money lent out is drawn as its own wedge;
  money borrowed joins the overdrawn accounts in the figure beneath the ring.
  Projected interest is shown and never counted: interest actually paid is an
  ordinary expense.
- A recurring rule is an instruction, not a record of money. It stamps out
  ordinary `MoneyTransaction` rows and nothing else reads it, so every balance,
  every total, and the category breakdown follow a generated entry exactly as
  they follow a typed one — and the owner can edit or delete that entry, because
  it records money that really moved. Every occurrence is measured from the
  rule's start date rather than from the previous one, so a rule anchored on the
  31st clamps to the end of February and comes straight back to the 31st in
  March instead of drifting. Nothing is ever recorded ahead of today: balances
  count every transaction whatever its date.
- Generation runs on launch and on returning to the foreground, never on a timer
  and never in the background, which is the rule market data already follows. A
  month spent away is a month recorded in full on the next open.
- The one network boundary is `FundQuoteTransport`, behind which every provider
  is tested against a recorded reply. The default test run makes no connection.
- Four identities are unique by a rule rather than by a database constraint: a
  category by its kind and name, an instrument by its ticker, the one
  `Unassigned` account by a fixed id, and a generated transaction by the pair of
  the rule that wrote it and the day it fell on. CloudKit forbids unique attributes, so the
  rule is enforced twice instead — by the draft before a write, and by
  `StoreReconciler` afterwards, which folds a duplicate into the older row and
  repoints everything naming it first, so no balance or history moves. Every
  foreign key that names an account defaults to the `Unassigned` one, so a
  record can always be counted somewhere rather than counted in a spending
  total and in no balance at all.
- `docs/architecture.html` draws every `@Model` with its fields and foreign
  keys, then the components around the app — Apple frameworks, the one
  third-party package, and the services still on the roadmap. Open it in any
  browser; it is one self-contained file with no build step and no external
  requests.
