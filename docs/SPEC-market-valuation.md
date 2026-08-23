# Spec: market-valuation

**Status:** Approved through owner direction (2026-08-23)
**Depends on:** `fund-etf-holdings` for slice 1; `investment-tracking` for slice 2
**Amends:** `SPEC-fund-etf-holdings.md` — splits `FundHolding` into an instrument
and a position. That spec's data contract is superseded by the one below;
everything else in it still stands.

## Objective

Replace the hand-entered price on every holding with one pulled from a market
data source, so a portfolio is worth what the market says it is worth rather
than what the owner last remembered to type.

`fund-etf-holdings` shipped with `currentNAVPerUnit` and `navAsOf` as owner
input, and listed "automatic NAV or price refresh, network access of any kind"
under Excluded. That was the right call for a first slice, and it is the reason
a holding silently drifts: nothing in the app knows the number is stale, so an
untouched portfolio quietly reports last month's value as today's.

### Why the model splits

Adding a refresh to the shipped shape would make an existing latent bug worse
rather than better. `FundHolding` stores the price on the **position**, and
nothing prevents two positions carrying the same ticker: `FundFormError` has no
`duplicateSymbol` case, and no call site in the app compares a symbol against
the ones already stored. Two rows for `FUEVFVND` can therefore hold two
different prices at the same moment, and net worth is wrong with nothing to
show for it.

A price is a property of the **instrument**, not of the position. Refresh makes
that concrete: fetching per holding would issue duplicate requests for one
ticker and could leave two rows disagreeing forever if one had automatic quotes
switched off.

So this module splits the model. `FundInstrument` is the catalogue — one row per
tradable thing, carrying its identity and its price. `FundHolding` keeps only
what belongs to a position: how many units, at what average cost, funded from
which account. Creating a holding becomes picking an instrument rather than
retyping its name, its ticker, and its kind.

This module also adds the **first network access in the app**. That boundary
gets its own contract below.

## Scope

### Slice boundary

`CAPABILITY-MAP.md` lists `market-valuation` as depending on
`investment-tracking`. Only its second half does:

- **Slice 1 — the fund catalogue and its quotes.** Depends on
  `fund-etf-holdings` alone and is buildable today. It owns the model split, the
  provider interface, the network boundary, the refresh flow, and staleness
  reporting.
- **Slice 2 — portfolio valuation.** Depends on `investment-tracking`, which does
  not exist yet. It extends the same provider interface to gold, equity, and
  crypto positions and adds portfolio-wide allocation and profit/loss.

Slice 2 stays specified but unbuilt until `investment-tracking` lands. Slice 1
must not be blocked behind it, and must not anticipate its data model.

**The catalogue is deliberately not generalised.** Gold, equities, and crypto
have the same duplication problem, but not the same shape — gold is priced by
chỉ or lượng, crypto carries eight decimal places, equities trade in board lots.
`FundInstrument` covers funds and ETFs and names the seam;
`investment-tracking` decides whether a shared `Instrument` abstraction is worth
having once its own units are known.

### User flow

1. Open the **Investments** tab. Each fund holding shows its market value and,
   below it, when that price is from.
2. A price older than the last completed trading day is marked stale in text and
   symbol, not by colour alone.
3. Choose **Refresh**. Each instrument shows that it is fetching.
4. Prices land one by one. Market value, unrealized profit or loss, and total
   assets move with them.
5. An instrument that fails keeps its previous price, and its row says why it did
   not update.
6. Choose **Add holding**. Pick an instrument from the catalogue, enter units and
   average cost, and choose a funding account. The name, the ticker, and the kind
   come from the instrument; there is nothing to retype.
7. The instrument is not in the catalogue yet, so choose **Add instrument** from
   the picker, search the provider by ticker, and confirm the name and kind it
   returns.
8. Open **Instruments** from the toolbar to edit a price by hand, see its source
   and fetch time, or turn automatic quotes off for a ticker no provider covers.
9. Relaunch and see the same holdings, the same prices, the same sources, and the
   same dates.

### Included

- A `FundInstrument` catalogue: one row per fund or ETF, unique by ticker,
  owning the price, its trading day, its source, and its fetch time.
- `FundHolding` reduced to a position pointing at an instrument.
- A one-time migration that builds the catalogue from existing holdings.
- Instrument selection when creating or editing a holding, replacing free-text
  name, ticker, and kind entry.
- A typed `FundQuoteProvider` interface with one implementation per instrument
  kind, selected from the instrument's own `kind`.
- Open-ended fund NAV from the Fmarket public API.
- Listed ETF closing price from the VNDIRECT chart API.
- Provider-backed instrument search when adding one to the catalogue.
- An owner-triggered refresh for all instruments, and for one from its editor.
- Staleness reporting against the last completed trading day.
- A per-instrument switch to opt out of automatic quotes.
- Manual price entry retained as an override and a fallback.
- Failure handling that never destroys a known-good price.
- Local caching and a per-ticker request floor, so a repeated Refresh does not
  hammer a provider.
- Fixture-driven tests with no network access in the default test run.

### Excluded

- Background, scheduled, or launch-time refresh. Every fetch is owner-triggered.
- Intraday or streaming prices. Slice 1 fetches one daily figure per instrument.
- Price history, charts, and performance over time.
- A market-holiday calendar. Staleness is computed from weekdays alone, and Tết
  is reported as stale rather than modelled.
- Currency conversion or any non-VND instrument.
- A shared instrument abstraction across asset classes.
- Gold, equity, and crypto quotes, portfolio allocation, and portfolio-wide
  profit and loss — all slice 2, blocked on `investment-tracking`.
- Individual trades, lots, realized profit and loss, dividends, and splits;
  `SPEC-fund-etf-holdings.md` still excludes these. The split makes several
  holdings per instrument *representable*, which is what a later lot model will
  need, but nothing in this module computes across them.
- Any write to a provider, any authenticated call, any brokerage integration.
- iCloud, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

```swift
enum FundInstrumentKind: String, Codable, CaseIterable, Sendable {
    case fund       // open-ended fund certificate, priced by NAV
    case etf        // listed on HOSE, priced by close
}

enum FundQuoteSource: String, Codable, CaseIterable, Sendable {
    case manual     // typed by the owner
    case fmarket    // open-ended fund NAV
    case vndirect   // listed ETF close
}

@Model
final class FundInstrument {
    var id: UUID
    var symbol: String                  // uppercased, unique across the catalogue
    var name: String
    var kind: FundInstrumentKind
    var currentPricePerUnit: Decimal
    var priceAsOf: Date                 // trading day the price belongs to
    var priceSource: String             // FundQuoteSource raw value
    var priceFetchedAt: Date?           // nil when the price was typed
    var autoQuoteEnabled: Bool
    var currencyCode: String
    var createdAt: Date
}

@Model
final class FundHolding {
    var id: UUID
    var instrumentID: UUID              // required
    var units: Decimal                  // fractional
    var averageCostPerUnit: Decimal
    var sourceAccountID: UUID?
    var createdAt: Date
}
```

`FundInstrumentKind` is a **typealias** for `FundHoldingKind`, not a rename.
Renaming the type looked free — the raw values never change — but SwiftData
hashes the attribute's Swift type name into the schema, and a renamed enum makes
an existing store unrecognisable (`Cannot use staged migration with an unknown
model version`). The alias gives new code the name that reads correctly while
the stored shape stays byte-identical.

Rules on the instrument:

- `symbol` is trimmed, uppercased, and must contain at least one non-whitespace
  character. It is **unique across the catalogue**, compared case-insensitively.
  Uniqueness is enforced in `FundInstrumentDraft`, not by
  `@Attribute(.unique)` — CloudKit forbids unique attributes, and the eventual
  `icloud-sync` module should inherit no schema debt here.
- `name` is trimmed and must contain at least one non-whitespace character.
- `currentPricePerUnit` must be greater than zero.
- `priceAsOf` is the **trading day the price belongs to**. `priceFetchedAt` is
  when the app asked. They differ by design: fetching on a Sunday returns
  Friday's figure, and conflating the two would report a weekend price that does
  not exist.
- `priceSource` is stored as a `String` raw value rather than the enum, matching
  how `kind` is persisted, so a future source can be added without a migration.
- `kind` decides which provider runs. Nothing a provider returns overrides it.

Rules on the holding:

- `instrumentID` is **not** optional. A position with no instrument has no
  identity, no price, and no way to be valued, which is the whole point of the
  record. It is the same reasoning that makes `MoneyTransaction.accountID`
  required.
- `units` must parse as a decimal greater than zero. Input accepts `1234,56`,
  `1234.56`, and grouped digits; anything else is rejected.
- `averageCostPerUnit` must parse as a decimal greater than zero.
- `sourceAccountID` is the funding account's `id`, or `nil` when the holding is
  not funded from a tracked account. Unchanged from `fund-etf-holdings`.
- `currencyCode` is **removed** from the holding. Cost and price are both in the
  instrument's currency, and storing it twice invites the two to disagree.
- Money, units, and rates use `Decimal`; `Double` and `Float` are forbidden.

### Valuation

`FundValuation` keeps its four pure functions and its rounding. Only where the
price comes from changes:

```swift
costBasis            = round(units × averageCostPerUnit)
marketValue          = round(units × instrument.currentPricePerUnit)
unrealizedProfitLoss = marketValue − costBasis
returnPercent        = costBasis > 0 ? (unrealizedProfitLoss / costBasis) × 100 : 0
```

Call sites pass the instrument's price in as a value, exactly as they passed the
holding's before. Nothing in `FundValuation` gains a `ModelContext`, a network,
a locale, or a clock.

`CashBalanceSummary.fundedAmount` still sums cost basis, which lives entirely on
the holding, so **the cash side of the app is untouched by this module**. Only
`AssetSummary.netWorth` and `AssetAllocation` need the instrument, and only to
read a price.

### Model split and backfill

Existing stores hold `FundHolding` rows carrying `name`, `symbol`, `kind`,
`currentNAVPerUnit`, `navAsOf`, and `currencyCode`.

The obvious way to move them is a `VersionedSchema` pair with a custom
`MigrationStage`. **That does not work here, and was tried first.** A store this
app has already written fails to open at all:

```
Cannot use staged migration with an unknown model version.
```

Staged migration has to recognise the store as the "from" version, and a store
created by an unversioned `ModelContainer(for:)` — every build shipped so far —
is not recognised. The failure lands inside `ModelContainer.init`, before there
is any UI to report it with, on the owner's real records.

So the schema change is kept **purely additive** and the linking happens after
the store is open:

- `FundInstrument` is a new entity.
- `FundHolding.instrumentID` is a new **optional**. `nil` means "not yet
  linked", never "held in nothing"; every write from `FundDraft` requires a
  choice.
- The six pre-split fields **stay declared** on `FundHolding` with defaults, so
  SwiftData opens the store with no migration at all. Nothing but the backfill
  reads them.
- `FundInstrumentBackfill.runIfNeeded(in:)` runs once at launch, after
  `CategorySeed`. It is idempotent, so it does nothing on every later launch.

Backfill rule, in order:

1. Fetch holdings where `instrumentID == nil`. Stop if there are none.
2. Group them by `symbol.uppercased()`. A holding with no symbol is skipped
   rather than collapsed into a nameless instrument.
3. Reuse an instrument the catalogue already carries for that ticker; otherwise
   create one. Take `name` and `kind` from the group's **oldest** holding by
   `createdAt`, so the first thing the owner entered wins over a later typo.
4. Take `currentPricePerUnit` and `priceAsOf` from the group's holding with the
   **newest** `navAsOf`. When two rows disagreed, the more recent price is the
   better guess and the older one was already wrong.
5. Point every holding in the group at that instrument.

No holding is deleted and no unit count, average cost, or funding link is
touched, so cost basis, funded amount, and every cash balance come out of it
identical. Only a duplicated ticker's *price* can change, and only towards the
more recent of the two figures it already held.

A backfill that throws is reported and the app still runs: holdings it could not
link render as "instrument missing" rather than taking the app down, and the
next launch tries again. That is only safe because the store already opened.

**The cost** is six dead columns on `FundHolding` until a later module drops
them, once every store has been through this. That is the price of a change
that cannot fail at launch, and it is the right trade for a store holding the
owner's only copy of their records.

### Providers

Both endpoints are **undocumented internal APIs**. They are unauthenticated and
serve public price data, and both were verified working on 2026-08-21. Neither
carries a service level, a compatibility promise, or a licence to reuse the
data. The design consequences are in Boundaries; the mechanics follow.

```swift
struct FundQuote: Sendable, Equatable {
    let symbol: String          // uppercased, as stored on the instrument
    let pricePerUnit: Decimal   // VND per unit, already normalised
    let asOf: Date              // start of the trading day the price belongs to
    let source: FundQuoteSource
}

struct FundInstrumentCandidate: Sendable, Equatable {
    let symbol: String
    let name: String
    let kind: FundInstrumentKind
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
    /// `asOf` is passed rather than read from the clock, so a provider test
    /// gets the same answer on any day it runs.
    func latestQuote(symbol: String, asOf: Date) async throws -> FundQuote
    func search(_ query: String) async throws -> [FundInstrumentCandidate]
}

struct FundQuoteRouter: Sendable {
    func provider(for kind: FundInstrumentKind) -> any FundQuoteProvider
    func latestQuote(symbol: String, kind: FundInstrumentKind, asOf: Date) async throws
        -> FundQuote
    // .fund -> FmarketQuoteProvider
    // .etf  -> VNDirectQuoteProvider
}
```

`SWIFT_STRICT_CONCURRENCY = complete` is already set in `Config/Base.xcconfig`,
so every type crossing the network boundary is `Sendable` and no provider holds
mutable state that a caller can reach.

**FmarketQuoteProvider — `.fund`**

Symbol to provider id, cached for the app session:

```
POST https://api.fmarket.vn/res/products/filter
{"searchField":"VESAF","types":["NEW_FUND","TRADING_FUND"],"pageSize":100}
-> data.rows[].id, data.rows[].shortName, data.rows[].nav
```

`shortName` is matched case-insensitively against the instrument's `symbol`. An
empty `searchField` with `pageSize: 100` returns the full catalogue — 68 funds
on 2026-08-21 — which is what `search(_:)` offers when adding an instrument.

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

The `/symbols` call backs `search(_:)` and supplies a candidate's display name.
Its `description` and `type` fields are **not trusted for classification**:
VESAF comes back as `type: "IFC"`, `exchange-traded: "HOSE"`,
`description: "VINACAPITAL VN100 ETF"`, all three wrong for an unlisted
open-ended fund. A candidate's `kind` is therefore whichever provider produced
it, and the owner confirms it before the instrument is saved.

The same endpoint also serves open-ended fund NAV, and the numbers match Fmarket
exactly — `31.51777` against Fmarket's `31517.77` for 2026-08-20. It is still not
used for `.fund` instruments, because it lags Fmarket by a trading day and
carries the wrong metadata.

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
    static func isStale(priceAsOf: Date, kind: FundInstrumentKind, asOf: Date) -> Bool
}
```

- Built on `TransactionPeriod.calendar` (Gregorian, `Asia/Ho_Chi_Minh`), reused
  rather than redefined, so no module reads the machine locale.
- The HOSE session is 09:00–15:00 on weekdays. Before 15:00 the last completed
  trading day is the previous weekday; from 15:00 it is today.
- Saturday and Sunday are not trading days. **Public holidays are not modelled.**
  A Tết week reports every price as stale, which is honest about what the app
  knows and better than a hardcoded holiday table going wrong in a later year.
- `.fund` instruments get one extra day of grace: Fmarket publishes NAV at T+1,
  so a fund whose `priceAsOf` is the trading day before last is current, not
  stale.
- Every function takes the date it needs. Nothing reads the clock, so tests are
  deterministic.

### Refresh policy

- Refresh is **owner-triggered only**. No timer, no background task, no fetch on
  launch or on tab appearance.
- Refresh iterates the **catalogue**, not the holdings. Ten positions in one
  ticker cost one request, and the duplicate-price failure mode the split
  removed cannot come back through the network path.
- An instrument no holding references is skipped. The catalogue may outlive a
  sold position, but a row nobody holds is not worth a request.
- A per-ticker floor of 15 minutes: a second Refresh inside that window reuses
  the stored price and returns `rateLimited` rather than calling out. The floor
  is in memory and resets on relaunch.
- An instrument whose `priceAsOf` is already the last completed trading day is
  skipped without a request.
- Instruments are fetched **sequentially**, not concurrently. A catalogue holds a
  handful of tickers; a parallel burst buys nothing and looks like abuse.
- Request timeout is 10 seconds. One retry on `transport`, none on any other
  error.
- `autoQuoteEnabled == false` excludes an instrument from Refresh and from
  staleness marking entirely.

### Failure policy

- A failed fetch **never** writes. The previous `currentPricePerUnit`,
  `priceAsOf`, `priceSource`, and `priceFetchedAt` all stand.
- A price is never replaced by zero, by nil, or by a placeholder.
- One ticker failing does not abort the others. Refresh reports per instrument.
- A successful fetch writes all four fields and calls `save()` once for the whole
  Refresh, rolling back and surfacing the error if the save fails.
- Editing a price by hand sets `priceSource = "manual"` and clears
  `priceFetchedAt`. A later Refresh overwrites it again unless
  `autoQuoteEnabled` is off — the override is a value, not a lock.

## Network Boundary

This is the app's first outbound connection, and the contract is narrow:

- **Only the ticker leaves the device.** No balance, no unit count, no cost
  basis, no account name, no identifier of the owner. A provider learns that
  somebody asked about `FUEVFVND` and nothing else. Never send a holding's
  quantity or value in a query, a header, or a body. The model split helps here
  too: the provider layer only ever sees `FundInstrument`, which carries no
  position data at all.
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

- **Refresh** (`refresh-quotes`) sits on the **Instruments** sheet, not on the
  Investments tab. Refresh walks the catalogue, and putting the control on the
  screen that shows the catalogue keeps the thing being refreshed in view
  while it happens. It is disabled while a refresh runs and when no held
  instrument has `autoQuoteEnabled`.
- Each `FundHoldingCard` shows the instrument's name and ticker as before, and
  gains one line under the market value: the price date and its source, worded
  per kind — "NAV 21 Aug 2026 · Fmarket" or "Close 21 Aug 2026 · VNDIRECT" or
  "Entered by hand".
- A stale price is marked with a symbol **and** the word "Stale", never colour
  alone. This follows the same rule as transaction direction in
  `SPEC-income-expense.md`.
- During a refresh each affected card shows a fetching state. A card whose fetch
  failed shows the reason in text — "Symbol not found", "No connection",
  "Nothing new to fetch" — and keeps its old figure visible.
- Refreshing changes market value, unrealized profit or loss, and total assets.
  It changes **no** cash balance: cost basis lives on the holding and is
  untouched, so the invested đồng is still counted exactly once, as
  `SPEC-fund-etf-holdings.md` requires.
- The **holding editor** loses its name, ticker, and kind fields. In their place
  sits one instrument picker (`holding-instrument`) listing the catalogue with
  ticker, name, and kind, plus an **Add instrument** row at its foot. The editor
  keeps units, average cost, funding account, and Delete.
- The picker's Add row opens the **instrument editor** (`instrument-editor`),
  which takes a ticker, searches the matching provider, and shows the candidate's
  name and kind for the owner to confirm or correct before saving. A provider
  that is unreachable does not block the flow: the owner may fill the name, the
  kind, and an opening price by hand.
- **Instruments** opens from the Investments toolbar (`manage-instruments`) as a
  sheet listing the catalogue, mirroring how Spending reaches Categories. Each
  row shows ticker, name, kind, price, price date, source, and whether anything
  is held. A row opens the instrument editor.
- The instrument editor carries an editable price field (`instrument-price`), a
  price-date field, an **Automatic quotes** toggle (`auto-quote`), and a Delete
  button behind a confirmation.
- **Not built yet:** a per-instrument **Fetch now** button (`fetch-quote`) in the
  instrument editor. Refresh already covers every held ticker, so this is only
  worth having when adding an instrument and wanting its price without leaving
  the form. Approved in principle, deliberately unbuilt.
- Deleting an instrument is **blocked while any holding references it**, and the
  reason names the count, matching how `cash-balance` and `account-transfer`
  guard an account: "This instrument is held by N positions. Delete them first."
- Errors appear inline with icon plus text, never colour alone.
- **Identifier changes.** `fund-name`, `fund-symbol`, `fund-kind`, `fund-nav`,
  and `fund-nav-date` leave the holding editor, because those fields leave it.
  `fund-name`, `fund-symbol`, and `fund-kind` are reused on the instrument
  editor for the same controls; `fund-nav` and `fund-nav-date` are replaced by
  `instrument-price` and `instrument-price-date`. `funds-list`, `add-fund`,
  `fund-units`, `fund-average-cost`, `fund-source`, `save-fund`, `cancel-fund`,
  and `delete-fund` are unchanged. This is the only identifier change since the
  Cash-to-Home rename in `SPEC-income-expense.md`.
- New accessibility identifiers: `refresh-quotes`, `manage-instruments`,
  `instrument-list`, `instrument-editor`, `holding-instrument`,
  `add-instrument`, `instrument-search`, `instrument-price`,
  `instrument-price-date`, `auto-quote`, `quote-source`,
  `quote-status`, `quote-error`, `save-instrument`, `cancel-instrument`,
  `delete-instrument`, `confirm-delete-instrument`.
- Screen copy stays English, matching the existing screens.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` holding `CashAccount`,
  `SavingsDeposit`, `FundInstrument`, `FundHolding`, `TransactionCategory`,
  `MoneyTransaction`, and `AccountTransfer` — seven models.
- `MonMonSchema.models` is the single list of registered models, used by the app
  container and by every in-memory test container so the two cannot drift.
- **No migration plan is installed.** Both changes are additive, so no store is
  ever asked to stage, and `ModelContainer.init` cannot fail on a store an
  earlier build wrote.
- Symbol uniqueness is enforced in the draft layer against a fetch of existing
  instruments, never by `@Attribute(.unique)`.
- Lists use SwiftData `@Query`; editors take `ModelContext` from the environment,
  insert only after validation, and call `save()` explicitly, rolling back and
  surfacing the error when it fails.
- The symbol-to-`productId` map for Fmarket is an in-memory cache with the
  lifetime of the app session. It is **not** persisted, and specifically not
  stored on `FundInstrument`: a stale id would silently fetch another fund's NAV,
  and re-fetching the catalogue costs one request.
- No response body is written to disk. Nothing is cached in `URLCache`.
- Every stored property stays non-optional or optional with a stable default, and
  no `@Attribute(.unique)` is introduced, so the eventual `icloud-sync` module
  inherits no schema debt from this module.
- Automated tests use `ModelConfiguration(isStoredInMemoryOnly: true)` and never
  touch the owner's database.

## Testing Strategy

The rule that shapes everything here: **no test in the default run touches the
network.** A suite that depends on Fmarket being up is a suite that fails on a
plane, and a green run must mean the code is right, not that the internet is.

Automated, fixture-driven:

- `FundInstrumentPersistenceTests` — field round trip; edit through the draft;
  delete; a duplicate ticker rejected case-insensitively; the same ticker
  allowed after the original is deleted.
- `FundHoldingPersistenceTests` — reshaped: a holding round trips with
  `instrumentID`; two holdings share one instrument and both value from its
  single price; deleting an instrument is blocked while a holding references it.
- `FundInstrumentBackfillTests` — an empty store backfills nothing; one legacy
  holding becomes one instrument it points at, with units, average cost, funding
  link, and cost basis untouched; two rows of one ticker collapse to one
  instrument taking identity from the older and price from the newer; two
  tickers become two instruments; running twice changes nothing the second time;
  a holding that already points somewhere is left alone; a legacy holding joins
  an instrument the catalogue already has without overwriting its price; a
  holding with no ticker is skipped.
- `FundInstrumentSeedTests` — grouping is case-insensitive and keeps first-seen
  order; an empty input produces no groups; a blank name falls back to the
  ticker.
- `FmarketQuoteProviderTests` — decode a recorded `/filter` body to id, symbol,
  and search candidates; decode a recorded `get-nav-history` body to the last
  point; VND needs no scaling; a missing symbol raises `symbolNotFound`; an
  empty `data` array raises `noQuoteAvailable`; a renamed field raises
  `decoding`; a non-2xx raises `transport`.
- `VNDirectQuoteProviderTests` — `34.2` decodes to `Decimal(34200)` exactly;
  `"s":"no_data"` raises `noQuoteAvailable`; a unix stamp maps to the right
  trading day in `Asia/Ho_Chi_Minh`; empty `c` raises `noQuoteAvailable`; a
  zero or negative close raises `decoding`.
- `FundQuoteRouterTests` — `.fund` routes to Fmarket, `.etf` to VNDIRECT, and
  the router consults the instrument's `kind` rather than anything in a provider
  response.
- `TradingCalendarTests` — a weekday before and after 15:00; Saturday and
  Sunday; a year boundary; the T+1 grace applied to `.fund` and not to `.etf`;
  a holiday correctly reported as stale.
- `FundPriceRefresherTests` — a successful fetch writes all four instrument
  fields; a
  failure writes none of them; one ticker failing leaves the others updated; ten
  holdings of one ticker cost one request; an unheld instrument is skipped; an
  instrument already on the last completed trading day is skipped without a
  request; the 15-minute floor returns `rateLimited`; `autoQuoteEnabled == false`
  is excluded; a hand edit sets the source back to `manual`.
- `FundValuationTests` and `AssetSummaryTests` gain a case where a refreshed
  price moves market value and net worth while every cash balance holds still,
  and a case where two holdings of one instrument both move from one refresh.
- Existing cash-balance, savings-deposit, income-expense, and account-transfer
  tests must keep passing untouched.

Fixtures are real responses captured on 2026-08-21 and committed as string
constants in `FundQuoteFixtures.swift`, rather than as bundled resources: the
test target needs no resource phase, and the recorded body sits beside the
test that reads it —
VESAF at 31,581.76 ₫ for 2026-08-21, FUEVFVND at 34.2 for the same day — so a
decoder change that breaks on real data is caught without a request.

One live smoke test may exist, guarded by an environment variable, excluded from
every command in Verification Commands, and never required for a green run.

Hands-on, owned by the owner:

- Creating a holding by picking an instrument, with nothing to retype.
- Adding an instrument the catalogue does not have, by ticker.
- Refreshing a catalogue holding both a fund and an ETF and checking each figure
  against Fmarket and a broker board by hand.
- Watching total assets move and every cash balance hold still.
- Holding the same ticker twice and confirming one refresh moves both.
- Refreshing twice inside a minute and seeing the second do nothing.
- Refreshing with the network off and confirming every price survives.
- A deliberately misspelled ticker reporting not-found and keeping its price.
- Typing over a fetched price, then refreshing, and seeing it fetched again.
- Turning automatic quotes off and confirming the instrument stops being marked
  stale.
- Blocked instrument deletion while a holding remains, with the count named.
- Upgrading a store that already holds funds, and checking every figure survived.
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

- Keep the price on the instrument and the position on the holding.
- Refresh over the catalogue, never over the holdings.
- Reject a duplicate ticker in the draft layer, case-insensitively.
- Send only the ticker over the network, and only when the owner asked.
- Keep manual price entry working as an override and a fallback.
- Keep a known-good price when a fetch fails.
- Store the trading day a price belongs to separately from when it was fetched.
- Build prices as `Decimal` from their textual form; never through `Double`.
- Scale VNDIRECT closes by 1000 and leave Fmarket NAV unscaled.
- Choose the provider from the instrument's `kind`, never from provider metadata.
- Report staleness in text and symbol as well as colour.
- Keep `openingBalance` and cost basis untouched; only market value moves.
- Keep both platform builds healthy after every increment.

### Ask first

- Refresh on a timer, in the background, or at launch.
- Add a third provider, or switch either existing one.
- Fetch intraday prices, or store any price history.
- Generalise `FundInstrument` across asset classes.
- Add `@Attribute(.unique)` anywhere.
- Add a market-holiday calendar.
- Start slice 2 before `investment-tracking` exists.
- Change persisted schema, user flow, copy language, or accessibility
  identifiers beyond the changes listed in the UI Contract.
- Enable iCloud.

### Never do

- Store a price on a holding, or let two records of one ticker carry two prices.
- Send a balance, a unit count, a cost basis, an account name, or any owner
  identifier to a provider.
- Store or transmit brokerage credentials, account numbers, API keys, or secrets.
- Persist a provider's internal id on a model.
- Add an App Transport Security exception, or accept an invalid certificate.
- Use `Double` or `Float` for a price, in decoding or in arithmetic.
- Overwrite a good price with zero, nil, or a placeholder on failure.
- Install a migration plan that can stop the app from opening its store.
- Read a pre-split field anywhere but the backfill.
- Delete an instrument a holding still references.
- Let a network failure block the app, or a refresh run without the owner asking.
- Treat a provider's `description` or `type` as authoritative about an
  instrument.
- Count the same đồng in both available cash and market value.
- Make a test in the default run depend on a live provider.

## Success Criteria

- A ticker exists exactly once in the catalogue, and a second attempt to add it
  is refused with a clear inline error.
- Creating a holding requires no typing of a name, a ticker, or a kind.
- Two holdings of one instrument always show the same price, and one refresh
  moves both.
- Refreshing a `.fund` instrument writes the NAV Fmarket publishes for that
  ticker, in đồng, dated to the trading day it belongs to.
- Refreshing a `.etf` instrument writes the VNDIRECT close × 1000, exactly, with
  no floating-point residue.
- Market value, unrealized profit or loss, and total assets move with a refreshed
  price; every cash balance and every cost basis stays where it was.
- Backfilling a populated store preserves every unit count, average cost,
  funding link, cost basis, and cash balance exactly, and collapses a duplicated
  ticker to its most recent price. Running it again changes nothing.
- The app opens a store written by any earlier build without a migration.
- A failed fetch leaves all four price fields untouched and says why in text.
- One ticker failing does not stop the rest of the refresh.
- A second refresh inside 15 minutes makes no request, and ten positions in one
  ticker cost one request.
- An instrument that no holding references makes no request.
- Staleness is correct across a weekday before and after 15:00, a weekend, and a
  fund's T+1 grace.
- Typing over a fetched price marks the instrument manual; turning automatic
  quotes off removes it from refresh and from staleness marking.
- An instrument held by a position cannot be deleted, and the reason names the
  count.
- Only tickers appear in outbound requests, verified by inspection.
- The full test suite passes with the network disabled.
- Tests, strict formatting, and both platform builds pass without new warnings.

## Open Questions

1. The six pre-split fields on `FundHolding` are dead weight once every store has
   been backfilled. `FundInstrumentBackfill` empties them as it goes and
   `isComplete(in:)` reports when nothing is left unlinked, so the condition for
   dropping the columns is answerable. Dropping them is still its own change.
2. `CAPABILITY-MAP.md` lists `market-valuation` as depending on
   `investment-tracking`. Slice 1 depends only on `fund-etf-holdings`. The map
   should either split the row or record that the dependency applies to slice 2
   alone. Left unedited pending owner direction.
3. Both providers are undocumented endpoints with no licence to reuse their data.
   That is acceptable for a private local app and is a decision to revisit before
   any distribution beyond the owner's own devices.
