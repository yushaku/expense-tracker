# Spec: market-valuation

**Status:** Draft, pending owner approval (2026-08-23)
**Depends on:** `fund-etf-holdings` for slice 1; `investment-tracking` for slice 2

## Objective

Replace the hand-entered price on every holding with one pulled from a market
data source, so a portfolio is worth what the market says it is worth rather
than what the owner last remembered to type.

`fund-etf-holdings` shipped with `currentNAVPerUnit` and `navAsOf` as owner
input, and listed "automatic NAV or price refresh, network access of any kind"
under Excluded. That was the right call for a first slice, and it is the reason
a holding silently drifts: nothing in the app knows the number is stale, so an
untouched portfolio quietly reports last month's value as today's.

After this module the owner presses Refresh, the app fetches a price per symbol,
writes it with the trading day it belongs to, and shows plainly how old every
figure is. Hand entry stays — as an override, and as the fallback for the day a
provider disappears.

This module adds the **first network access in the app**. That boundary gets its
own contract below.

## Scope

### Slice boundary

`CAPABILITY-MAP.md` lists `market-valuation` as depending on
`investment-tracking`. Only its second half does:

- **Slice 1 — fund and ETF quotes.** Depends on `fund-etf-holdings` alone and is
  buildable today. It owns the provider interface, the network boundary, the
  refresh flow, and staleness reporting.
- **Slice 2 — portfolio valuation.** Depends on `investment-tracking`, which does
  not exist yet. It extends the same provider interface to gold, equity, and
  crypto positions and adds portfolio-wide allocation and profit/loss.

Slice 2 stays specified but unbuilt until `investment-tracking` lands. Slice 1
must not be blocked behind it, and must not anticipate its data model.

### User flow

1. Open the **Funds** tab. Each holding card carries its market value and, below
   it, when that price is from.
2. A price older than the last completed trading day is marked stale in text and
   symbol, not by colour alone.
3. Choose **Refresh**. Each holding shows that it is fetching.
4. Prices land one by one. Market value, unrealized profit or loss, and total
   assets move with them.
5. A symbol that fails keeps its previous price, and its card says why it did not
   update.
6. Open a holding and see the price source and its fetch time. The price field is
   still editable; typing over a fetched price marks the holding manual again.
7. Press **Fetch** beside the symbol inside the editor to pull one price without
   leaving the form.
8. Turn off automatic quotes for a holding whose symbol no provider covers, and
   it stops being marked stale.
9. Relaunch and see the same prices, the same sources, and the same dates.

### Included

- A typed `FundQuoteProvider` interface with one implementation per instrument
  type, selected by `FundHoldingKind`.
- Open-ended fund NAV from the Fmarket public API.
- Listed ETF closing price from the VNDIRECT chart API.
- An owner-triggered refresh for all holdings, and for one holding from its
  editor.
- Recorded quote source and fetch time per holding, distinct from the trading
  day the price belongs to.
- Staleness reporting against the last completed trading day.
- A per-holding switch to opt out of automatic quotes.
- Manual price entry retained as an override and a fallback.
- Failure handling that never destroys a known-good price.
- Local caching and a per-symbol request floor, so a repeated Refresh does not
  hammer a provider.
- Fixture-driven tests with no network access in the default test run.

### Excluded

- Background, scheduled, or launch-time refresh. Every fetch is owner-triggered.
- Intraday or streaming prices. Slice 1 fetches one daily figure per symbol.
- Price history, charts, and performance over time.
- A market-holiday calendar. Staleness is computed from weekdays alone, and Tết
  is reported as stale rather than modelled.
- Currency conversion or any non-VND instrument.
- Gold, equity, and crypto quotes, portfolio allocation, and portfolio-wide
  profit and loss — all slice 2, blocked on `investment-tracking`.
- Individual trades, lots, realized profit and loss, dividends, and splits;
  `SPEC-fund-etf-holdings.md` still excludes these.
- Any write to a provider, any authenticated call, any brokerage integration.
- iCloud, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

```swift
enum FundQuoteSource: String, Codable, CaseIterable, Sendable {
    case manual         // typed by the owner; the fund-etf-holdings default
    case fmarket        // open-ended fund NAV
    case vndirect       // listed ETF close
}

struct FundQuote: Sendable, Equatable {
    let symbol: String          // uppercased, as stored on the holding
    let pricePerUnit: Decimal   // VND per unit, already normalised
    let asOf: Date              // start of the trading day the price belongs to
    let source: FundQuoteSource
}

enum FundQuoteError: Error, Equatable {
    case symbolNotFound         // provider has no such symbol
    case noQuoteAvailable       // symbol exists, no usable data point
    case transport              // offline, timeout, non-2xx
    case decoding               // response shape changed
    case rateLimited            // refused by the local request floor
}

protocol FundQuoteProvider: Sendable {
    var source: FundQuoteSource { get }
    func latestQuote(symbol: String) async throws -> FundQuote
}
```

`FundQuoteRouter` owns provider selection and is the only thing that knows the
mapping:

```swift
struct FundQuoteRouter: Sendable {
    func provider(for kind: FundHoldingKind) -> FundQuoteProvider
    // .fund -> FmarketQuoteProvider
    // .etf  -> VNDirectQuoteProvider
}
```

`SWIFT_STRICT_CONCURRENCY = complete` is already set in `Config/Base.xcconfig`,
so every type crossing the network boundary is `Sendable` and no provider holds
mutable state that a caller can reach.

### Schema change

`FundHolding` gains three stored properties. This is the only schema change:

```swift
var navSource: String       // FundQuoteSource raw value; defaults to "manual"
var navFetchedAt: Date?     // when the app last fetched successfully; nil when manual
var autoQuoteEnabled: Bool  // defaults to true
```

- `currentNAVPerUnit` and `navAsOf` keep their names and meanings.
  `currentNAVPerUnit` already held whatever the owner typed; it now holds
  whatever was fetched, in the same units.
- `navAsOf` is the **trading day the price belongs to**. `navFetchedAt` is when
  the app asked. They differ by design: fetching on a Sunday returns Friday's
  figure, and conflating the two would report a weekend price that does not
  exist.
- `navSource` is stored as a `String` raw value rather than the enum, matching
  how `kind` is persisted, so a future source can be added without a migration.
- All three are non-optional or optional with a stable default, so the eventual
  `icloud-sync` module inherits no schema debt.
- Adding properties is an additive SwiftData change; the existing local store
  opens without migration work. Records written before this module read back as
  `manual`, `nil`, and `true`.

### Naming: NAV versus price

For a `.fund` holding, `currentNAVPerUnit` is genuinely the NAV per unit. For a
`.etf` holding it is the **closing market price**, which is not the ETF's NAV —
a listed ETF trades at a premium or discount to its NAV, and the gap is real
rather than error.

The field is **not** renamed in this module. Renaming would touch
`FundHolding`, `FundDraft`, `FundValuation`, both editor views, and every fund
test, for no behavioural gain. Instead the UI labels the field by kind — "NAV per
unit" for a fund, "Market price per unit" for an ETF — and this spec is the
record of the dual meaning. A rename moves through spec approval on its own.

### Providers

Both endpoints are **undocumented internal APIs**. They are unauthenticated and
serve public price data, and both were verified working on 2026-08-21. Neither
carries a service level, a compatibility promise, or a licence to reuse the
data. The design consequences are in Boundaries; the mechanics follow.

**FmarketQuoteProvider — `.fund`**

Symbol to provider id, cached for the app session:

```
POST https://api.fmarket.vn/res/products/filter
{"searchField":"VESAF","types":["NEW_FUND","TRADING_FUND"],"pageSize":100}
-> data.rows[].id, data.rows[].shortName, data.rows[].nav
```

`shortName` is matched case-insensitively against the holding's `symbol`. An
empty `searchField` with `pageSize: 100` returns the full catalogue — 68 funds
on 2026-08-21 — which is how the editor offers a symbol picker.

NAV for a day:

```
POST https://api.fmarket.vn/res/product/get-nav-history
{"isAllData":1,"productId":23,"fromDate":null,"toDate":"20260823"}
-> data[].navDate ("yyyy-MM-dd"), data[].nav
```

`isAllData` must be `1`; `0` returns HTTP 400. The response is the fund's whole
history — 1492 points for VESAF — so the provider takes the last entry and
discards the rest rather than storing a series.

`nav` is **VND per unit directly**. No scaling.

**VNDirectQuoteProvider — `.etf`**

```
GET https://dchart-api.vndirect.com.vn/dchart/history
      ?symbol=FUEVFVND&resolution=D&from=<unix>&to=<unix>
-> {"s":"ok","t":[<unix seconds>],"c":[<close>], ...}

GET https://dchart-api.vndirect.com.vn/dchart/symbols?symbol=FUEVFVND
-> {"exchange-traded":"HOSE","type":"ETF","session":"0900-1500", ...}
```

`c` is in **thousands of VND** and must be multiplied by 1000: `34.2` is
34,200 ₫. `t` is a unix second stamp for the trading day, converted in
`Asia/Ho_Chi_Minh`. `s` is `"ok"` on success; anything else is
`noQuoteAvailable`.

`from` is set 30 days back so a symbol suspended for a fortnight still yields
its last close.

The `/symbols` call validates a symbol before it is saved and supplies the
display name. Its `description` and `type` fields are **not trusted for
classification**: VESAF comes back as `type: "IFC"`, `exchange-traded: "HOSE"`,
`description: "VINACAPITAL VN100 ETF"`, all three wrong for an unlisted
open-ended fund. Only `FundHoldingKind`, which the owner sets, decides which
provider runs.

The same endpoint also serves open-ended fund NAV, and the numbers match Fmarket
exactly — `31.51777` against Fmarket's `31517.77` for 2026-08-20. It is still not
used for `.fund` holdings, because it lags Fmarket by a trading day and carries
the wrong metadata.

### Decimal safety

Prices arrive as JSON numbers. Decoding one into `Double` and multiplying by
1000 is how a fund tracker starts reporting 34199.999999996.

- Read the number's textual form from the parsed JSON and build the value with
  `Decimal(string:)`. A price never passes through `Double` or `Float`, in
  decoding or in arithmetic — this extends the existing rule in
  `SPEC-fund-etf-holdings.md` to the network boundary.
- The ×1000 scaling for VNDIRECT is `Decimal` multiplication.
- A parsed price must be greater than zero; zero or negative is `decoding`, not
  a price.
- `FundValuation` is untouched. It stays pure, and rounding to the đồng still
  happens exactly where it did.

### Trading days and staleness

```swift
enum TradingCalendar {
    static func lastCompletedTradingDay(asOf: Date) -> Date
    static func isStale(navAsOf: Date, asOf: Date) -> Bool
}
```

- Built on `TransactionPeriod.calendar` (Gregorian, `Asia/Ho_Chi_Minh`), reused
  rather than redefined, so no module reads the machine locale.
- The HOSE session is 09:00–15:00 on weekdays. Before 15:00 the last completed
  trading day is the previous weekday; from 15:00 it is today.
- Saturday and Sunday are not trading days. **Public holidays are not modelled.**
  A Tết week reports every price as stale, which is honest about what the app
  knows and better than a hardcoded holiday table going wrong in a later year.
- `.fund` holdings get one extra day of grace: Fmarket publishes NAV at T+1, so a
  fund whose `navAsOf` is the trading day before last is current, not stale.
- Every function takes the date it needs. Nothing reads the clock, so tests are
  deterministic.

### Refresh policy

- Refresh is **owner-triggered only**. No timer, no background task, no fetch on
  launch or on tab appearance.
- A per-symbol floor of 15 minutes: a second Refresh inside that window reuses
  the stored price and returns `rateLimited` rather than calling out. The floor
  is in memory and resets on relaunch.
- A holding whose `navAsOf` is already the last completed trading day is skipped
  without a request.
- Holdings are fetched **sequentially**, not concurrently. A portfolio holds a
  handful of symbols; a parallel burst buys nothing and looks like abuse.
- Request timeout is 10 seconds. One retry on `transport`, none on any other
  error.
- `autoQuoteEnabled == false` excludes a holding from Refresh and from staleness
  marking entirely.

### Failure policy

- A failed fetch **never** writes. The previous `currentNAVPerUnit`, `navAsOf`,
  `navSource`, and `navFetchedAt` all stand.
- A price is never replaced by zero, by nil, or by a placeholder.
- One symbol failing does not abort the others. Refresh reports per holding.
- A successful fetch writes all four fields and calls `save()` once for the whole
  Refresh, rolling back and surfacing the error if the save fails.
- Editing the price by hand sets `navSource = "manual"` and clears
  `navFetchedAt`. A later Refresh overwrites it again unless `autoQuoteEnabled`
  is off — the override is a value, not a lock.

## Network Boundary

This is the app's first outbound connection, and the contract is narrow:

- **Only the ticker leaves the device.** No balance, no unit count, no cost
  basis, no account name, no identifier of the owner. A provider learns that
  somebody asked about `FUEVFVND` and nothing else. Never send a holding's
  quantity or value in a query, a header, or a body.
- No credentials, tokens, cookies, or API keys are sent or stored. Both providers
  are unauthenticated, and the app must not gain a keychain entry for them.
- HTTPS only. App Transport Security keeps its defaults; no exception domain is
  added, and both hosts serve valid TLS.
- No analytics, no crash reporting, no third-party SDK arrives with this module.
- A default `URLSession` with an ephemeral configuration, no cookie storage, and
  no credential storage.
- The macOS target is not sandboxed today, so no entitlement is required. If the
  sandbox is ever enabled, `com.apple.security.network.client` is the only key
  this module needs — never `network.server`.
- Every request is triggered by an owner action. The app makes no connection the
  owner did not ask for.

## UI Contract

- The **Funds** tab keeps its layout. Its toolbar gains a **Refresh** button
  (`refresh-quotes`), disabled while a refresh runs and when no holding has
  `autoQuoteEnabled`.
- Each `FundHoldingCard` gains one line under the market value: the price date
  and its source, worded per kind — "NAV 21 Aug 2026 · Fmarket" or
  "Close 21 Aug 2026 · VNDIRECT" or "Entered by hand".
- A stale price is marked with a symbol **and** the word "Stale", never colour
  alone. This follows the same rule as transaction direction in
  `SPEC-income-expense.md`.
- During a refresh each affected card shows a fetching state. A card whose fetch
  failed shows the reason in text — "Symbol not found", "No connection",
  "Nothing new to fetch" — and keeps its old figure visible.
- Refreshing changes market value, unrealized profit or loss, and total assets.
  It changes **no** cash balance: cost basis is untouched, so the invested đồng
  is still counted exactly once, as `SPEC-fund-etf-holdings.md` requires.
- The fund editor gains, beside the symbol field, a **Fetch** button
  (`fetch-fund-quote`) that pulls one price into the form without saving, and a
  quote-source row showing the source and fetch time.
- The editor gains an **Automatic quotes** toggle (`auto-quote`). Turning it off
  greys nothing — the price field is always editable — it only removes the
  holding from Refresh and from staleness marking.
- The price field's label follows `kind`: "NAV per unit" for a fund, "Market
  price per unit" for an ETF. Its accessibility identifier stays `fund-nav`, so
  no identifier from `SPEC-fund-etf-holdings.md` changes.
- Errors appear inline with icon plus text, never colour alone.
- New accessibility identifiers: `refresh-quotes`, `fetch-fund-quote`,
  `auto-quote`, `quote-source`, `quote-status`, `quote-error`.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- The `ModelContainer` registration is unchanged; no model is added.
- `FundHolding` gains three stored properties as an additive schema change.
- Refresh runs off a `ModelContext` taken from the environment, writes only
  fetched values, and calls `save()` once, rolling back on failure.
- The symbol-to-`productId` map for Fmarket is an in-memory cache with the
  lifetime of the app session. It is **not** persisted: a stale id would silently
  fetch another fund's NAV, and re-fetching the catalogue costs one request.
- No response body is written to disk. Nothing is cached in `URLCache`.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database.

## Testing Strategy

The rule that shapes everything here: **no test in the default run touches the
network.** A suite that depends on Fmarket being up is a suite that fails on a
plane, and a green run must mean the code is right, not that the internet is.

Automated, fixture-driven:

- `FmarketQuoteProviderTests` — decode a recorded `/filter` body to id and
  symbol; decode a recorded `get-nav-history` body to the last point; VND needs
  no scaling; a missing symbol raises `symbolNotFound`; an empty `data` array
  raises `noQuoteAvailable`; a renamed field raises `decoding`; a non-2xx raises
  `transport`.
- `VNDirectQuoteProviderTests` — `34.2` decodes to `Decimal(34200)` exactly;
  `"s":"no_data"` raises `noQuoteAvailable`; a unix stamp maps to the right
  trading day in `Asia/Ho_Chi_Minh`; empty `c` raises `noQuoteAvailable`; a
  zero or negative close raises `decoding`.
- `FundQuoteRouterTests` — `.fund` routes to Fmarket, `.etf` to VNDIRECT, and
  the router consults `kind` rather than anything in a provider response.
- `TradingCalendarTests` — a weekday before and after 15:00; Saturday and
  Sunday; a year boundary; the T+1 grace applied to `.fund` and not to `.etf`;
  a holiday correctly reported as stale.
- `FundRefreshTests` — a successful fetch writes all four fields; a failure
  writes none of them; one symbol failing leaves the others updated; a holding
  already on the last completed trading day is skipped without a request; the
  15-minute floor returns `rateLimited`; `autoQuoteEnabled == false` is
  excluded; a hand edit sets the source back to `manual`.
- `FundValuationTests` and `AssetSummaryTests` gain a case where a refreshed
  price moves market value and net worth while every cash balance holds still.
- Existing cash-balance, savings-deposit, fund, income-expense, and
  account-transfer tests must keep passing.

Fixtures are real responses captured on 2026-08-21 and committed as files —
VESAF at 31,581.76 ₫ for 2026-08-21, FUEVFVND at 34.2 for the same day — so a
decoder change that breaks on real data is caught without a request.

One live smoke test may exist, guarded by an environment variable, excluded from
every command in Verification Commands, and never required for a green run.

Hands-on, owned by the owner:

- Refreshing a portfolio holding both a fund and an ETF and checking each figure
  against Fmarket and a broker board by hand.
- Watching total assets move and every cash balance hold still.
- Refreshing twice inside a minute and seeing the second do nothing.
- Refreshing with the network off and confirming every price survives.
- A deliberately misspelled symbol reporting not-found and keeping its price.
- Typing over a fetched price, then refreshing, and seeing it fetched again.
- Turning automatic quotes off and confirming the holding stops being marked
  stale.
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

- Send only the ticker over the network, and only when the owner asked.
- Keep manual price entry working as an override and a fallback.
- Keep a known-good price when a fetch fails.
- Store the trading day a price belongs to separately from when it was fetched.
- Build prices as `Decimal` from their textual form; never through `Double`.
- Scale VNDIRECT closes by 1000 and leave Fmarket NAV unscaled.
- Choose the provider from `FundHoldingKind`, never from provider metadata.
- Report staleness in text and symbol as well as colour.
- Keep `openingBalance` and cost basis untouched; only market value moves.
- Keep both platform builds healthy after every increment.

### Ask first

- Refresh on a timer, in the background, or at launch.
- Add a third provider, or switch either existing one.
- Fetch intraday prices, or store any price history.
- Rename `currentNAVPerUnit`, or split it per `kind`.
- Add a market-holiday calendar.
- Start slice 2 before `investment-tracking` exists.
- Change persisted schema, user flow, copy language, or accessibility identifiers.
- Enable iCloud.

### Never do

- Send a balance, a unit count, a cost basis, an account name, or any owner
  identifier to a provider.
- Store or transmit brokerage credentials, account numbers, API keys, or secrets.
- Add an App Transport Security exception, or accept an invalid certificate.
- Use `Double` or `Float` for a price, in decoding or in arithmetic.
- Overwrite a good price with zero, nil, or a placeholder on failure.
- Let a network failure block the app, or a refresh run without the owner asking.
- Treat a provider's `description` or `type` as authoritative about an
  instrument.
- Count the same đồng in both available cash and market value.
- Make a test in the default run depend on a live provider.

## Success Criteria

- Refreshing a `.fund` holding writes the NAV Fmarket publishes for that symbol,
  in đồng, dated to the trading day it belongs to.
- Refreshing a `.etf` holding writes the VNDIRECT close × 1000, exactly, with no
  floating-point residue.
- Market value, unrealized profit or loss, and total assets move with a refreshed
  price; every cash balance and every cost basis stays where it was.
- A failed fetch leaves all four price fields untouched and says why in text.
- One symbol failing does not stop the rest of the refresh.
- A second refresh inside 15 minutes makes no request.
- A holding already priced at the last completed trading day makes no request.
- Staleness is correct across a weekday before and after 15:00, a weekend, and a
  fund's T+1 grace.
- Typing over a fetched price marks the holding manual; turning automatic quotes
  off removes it from refresh and from staleness marking.
- Only tickers appear in outbound requests, verified by inspection.
- The full test suite passes with the network disabled.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

1. `CAPABILITY-MAP.md` lists `market-valuation` as depending on
   `investment-tracking`. Slice 1 depends only on `fund-etf-holdings`. The map
   should either split the row or record that the dependency applies to slice 2
   alone. Left unedited pending owner direction.
2. Both providers are undocumented endpoints with no licence to reuse their data.
   That is acceptable for a private local app and is a decision to revisit before
   any distribution beyond the owner's own devices.
