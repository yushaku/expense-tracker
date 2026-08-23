# MonMon

MonMon is a private personal-finance app for iPhone and Mac, themed with
Catppuccin — Latte in light, Frappé in dark. It has five slices today.
`cash-balance` lets one owner add, edit, and delete local cash, bank, and credit
card accounts with a VND opening balance. `savings-deposit` adds term
deposits (sổ tiết kiệm) with maturity dates, projected interest, and an optional
funding account, plus a total-assets figure that counts transferred money only
once. `fund-etf-holdings` adds fund certificates (chứng chỉ quỹ) and ETFs held in
units, valued at a hand-entered NAV, showing cost basis, market value, and
unrealized profit or loss. `income-expense` records money in and out against one
account each, grouped by categories the owner manages, so every balance follows
what was recorded rather than a hand-edited number.

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
rtk swift format lint --strict --recursive MonMon MonMonTests
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
  edit, and delete fund and ETF holdings valued at a hand-entered NAV, both
  under one Investments tab that totals them together; record
  income and expenses against one account each under owner-managed categories,
  browsed a day, a month, a year, or a hand-picked range at a time; add, edit,
  and delete transfers between two accounts, opened from the Home toolbar; an
  optional funding link that lowers an account's available balance without
  touching its opening balance; VND validation and formatting, exact `Decimal`
  totals, on-device SwiftData persistence, and shared SwiftUI UI.
- Owner validation: form behavior, interest and valuation against a hand
  calculation, relaunch persistence, iPhone Dynamic Type and keyboard, and Mac
  window resizing.
- Settings: a light/dark/system theme, and an optional Face ID, Touch ID, or
  passcode lock that hides the screen on launch and after a minute away. The
  lock is a gate on the screen, not encryption; the records on disk are
  protected by the operating system's file protection and nothing more.
- Not included yet: budgets, recurring transactions, interest paid on a
  schedule, rollover or early withdrawal, individual buy/sell trades or realized
  profit and loss, automatic price refresh, iCloud, network access, AI, or MCP.

## Architecture

- One multiplatform app target shares SwiftUI source between iOS and macOS.
- One dependency: [MijickCalendarView](https://github.com/Mijick/CalendarView)
  (MIT), which draws the calendar inside `DateField`. It is plain SwiftUI on
  both platforms and touches nothing but the view it is asked to draw. The
  resolved version is pinned in `Package.resolved`.
- SwiftData stores `CashAccount`, `SavingsDeposit`, `FundHolding`,
  `TransactionCategory`, `MoneyTransaction`, and `AccountTransfer` records
  locally; `@Query` drives every visible list and combined total.
- `AccountDraft`, `SavingsDraft`, `FundDraft`, `TransactionDraft`,
  `CategoryDraft`, and `TransferDraft` validate external text before any model is
  inserted or mutated, and money uses `Decimal` throughout.
- A savings deposit and a fund holding each store their funding account's `id`;
  available balances and total assets are derived, so deleting one needs no
  compensating write.
- A holding's cost basis leaves the cash side while its market value enters the
  asset side, so invested money is counted once and a gain shows as growth.
- A transaction stores a positive amount and carries its direction in `kind`, so
  no call site has to agree on a sign convention. An account's available balance
  is its opening balance plus recorded flow minus what it funds; the opening
  balance itself is never rewritten.
- A transfer stores a positive amount too, and the pair of accounts it names
  carries the direction. It is neither income nor an expense, so it never
  reaches the Spending totals, and because one account's outflow is another's
  inflow it leaves total assets untouched.
- The approved boundaries and verification contracts live under `docs/`:
  `SPEC-cash-balance.md`, `SPEC-savings-deposit.md`,
  `SPEC-fund-etf-holdings.md`, `SPEC-income-expense.md`, and
  `SPEC-account-transfer.md`. `SPEC-market-valuation.md` is drafted but not
  approved.
  `SPEC-market-valuation.md` amends the fund data contract: it splits
  `FundHolding` into a `FundInstrument` catalogue that owns the price and a
  position that points at it, so one ticker cannot carry two prices and a
  holding is created by picking rather than retyping.
- `docs/architecture.html` draws the same picture the specs describe in prose:
  every `@Model` with its fields and foreign keys, then the components around
  the app — Apple frameworks, the one third-party package, and the services
  still on the roadmap. Open it in any browser; it is one self-contained file
  with no build step and no external requests.
