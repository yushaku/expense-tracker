# Performance ledger

What has been tried against jank in MonMon, why, and where it stands. One row
per idea. "Expected" is reasoning from the code, not a measurement: nothing
here has been timed on the iPhone yet. Confirm on the device (Instruments,
SwiftUI template, Hitches and View Body lanes) before calling any of it done.

Reported on a physical iPhone with a few thousand `MoneyTransaction` rows:

1. Scrolling Transactions and other data-heavy screens stutters.
2. Swiping a transaction row left or right always hitches.
3. Sheets hitch while presenting or being dragged.
4. Swiping a sheet down to dismiss hitches the same way.

## Shipped on `perf/transaction-gestures`

| # | Idea | Cause found | Change | Expected effect | Symptoms | Status |
|---|------|-------------|--------|-----------------|----------|--------|
| 1 | Lazy history rows | `TransactionListSection` used a plain `VStack`, so every row of the period was built and laid out, and rebuilt on each update of the screen. Each row also did three linear searches (category, account, trip) and each day header re-summed its entries. | `LazyVStack`; `TransactionRowLookup` dictionaries built once per update; day net stored when the day is grouped. | Only rows near the viewport exist; an update costs O(visible) instead of O(period). | 1, 2 | Done, unit tested |
| 2 | No ledger-wide query on Transactions | `TransactionListView` held unfiltered `@Query`s over all transactions and transfers and filtered, grouped and summed them (plus the featured trip over the whole ledger) in `body`. That body re-runs for every sheet presented or dismissed from the screen, every swipe that opens the editor, and every import-inbox refresh. | History moved to `SpendingHistory` with a range-predicated `@Query`; featured trip queries only its own transactions; filter sheet counts a draft by fetching the draft's period (`LedgerFetch.resultCount`); goals sheet fetches only the month its capacity reads. | Sheet present/dismiss and swipe-to-edit no longer start with a scan of thousands of rows on the main thread. A probe on macOS confirmed SwiftUI skips a child whose inputs are a `Binding` and model arrays when the parent updates for unrelated state. | 2, 3, 4, 1 | Done, unit tested |
| 3 | Category usage in one pass | `CategoryListView` called `TransactionSummary.count` (a ledger scan) once per category row. | `TransactionSummary.countsByCategory` once per body. | Categories sheet body drops from O(categories x ledger) to O(ledger). | 3, 4 | Done, unit tested |
| 4 | Report figures out of the sheet-driving body | `ReportView` computed every card in the same body that owns `editorMode` and `isFiltering`. | Ledger query and content moved to `ReportContent`, which only takes the query and breakdown bindings and the small lists. | Opening or dismissing Report's filter sheet or editor no longer recomputes the report. | 3, 4 | Done |
| 5 | Category editor reads its own rows only | `CategoryEditorView` filtered the whole ledger for the usage count on every keystroke and while presenting; the add sheet fetched every transaction it never reads. | `@Query` cut to the edited category (`LedgerFetch.transactions(inCategory:)`), nothing when adding. | Typing and presenting the editor stop scanning the ledger. | 3 | Done, unit tested |
| 6 | Cached date format styles | `AppDateFormat.style` built a new `VerbatimFormatStyle` (calendar copy, locale) per call; every row and day header formats a date. | One static style per format, plus the GMT ledger-day style. | Less allocation per visible row update. Small. | 1 | Done, covered by existing tests |
| 7 | Day and category screens fetch their period | `DayTransactionsView` and `CategoryTransactionsView` filtered the whole ledger (and all transfers) in `body`, which re-runs when their sheets open or close. | Range-predicated `@Query` in `init`; in-memory filters kept. | Same as 2 for these pushed screens. | 1, 3, 4 | Done |

## Shipped on `perf/screens`

Expected effects are reasoning from the code, as above. Each row has a
commit of its own; parity tests pin the figures where a fetch was narrowed.

| # | Idea | Cause found | Change | Expected effect | Symptoms | Status |
|---|------|-------------|--------|-----------------|----------|--------|
| 8 | Account balances in one pass | `CashBalanceSummary.available` rescans the ledger for one account. Wealth called it per account for the ring and again for liabilities (each evaluated twice per body); every `CashAccountCard` called it two to three times, doubled by `ViewThatFits`. | `CashBalanceSummary.balances` returns `[UUID: Decimal]` in one pass, same term order; Wealth and the accounts section compute it once per body and derive slices with `let`; the card takes its balance as a `Decimal`. | Wealth body drops from roughly O(cards x 6 x ledger) to O(ledger). | 1, 3, 4 | Done, parity tested |
| 9 | Account detail reads its own rows | `AccountDetailView` held eleven unfiltered queries, filtered the period twice, searched linearly per row action, and owned the trend metric. | Transactions, transfers (either end) and payments predicated on the account in `init`; period filtered once; tab and metric `@State` in a child; dictionary lookups. | Opening an account and flipping its tabs or metric stop touching the whole ledger. | 1, 3, 4 | Done, fetch tested |
| 10 | Plan month computed once | `BudgetScreen` evaluated `snapshot` about four times per body over the whole ledger, the goal capacity per jar row, and `TripSummary` per trip, in the body that owns sheets and navigation; `asOf` was a `.now` default (stale after midnight, new on every rebuild). | `BudgetContent` child fetches the visible month (plus the `asOf` month for capacity), keeps the exact `<= asOf` cutoff, computes snapshot, capacity and commitments once; shell keeps sheet and nav state and passes bindings the content only writes; trips via `LedgerFetch.tripTransactions`; today in `@State` refreshed on appear, `scenePhase == .active` and `NSCalendarDayChanged` (`refreshesCurrentDate`), also for `GoalDetailView(workspace:)`. | Plan updates cost one month, and opening its sheets no longer recomputes it. | 1, 3, 4 | Done, parity tested |
| 11 | Editors check one account | Transfer, savings, fund, debt and debt payment editors each held about nine whole-table queries just for one account's balance; the transfer form recomputed it per keystroke. | `CashBalanceFetch.available` fetches only rows that can move the account (debts whole); called at save validation; the transfer form keeps it in `@State`, refreshed when the source changes. | Presenting an editor no longer fetches the ledger; typing stops rescanning it. | 3 | Done, parity tested |
| 12 | Recurring catch-up skips the ledger | `RecurringGenerator.generate` fetched every transaction on each launch and foreground before knowing anything was due. | Pending dates first, early return when none; otherwise fetch only generated rows from the first pending day through the last. | Launch and foreground skip a full fetch in a caught-up store. | launch | Done, unit tested |
| 13 | Segmented tabs animate the capsule only | The selection write was wrapped in `withAnimation`, so every view the parent rebuilt ran inside an animation. | A private displayed `@State` drives capsule and label style and is the only thing animated; the binding is written plainly. | Switching tabs on report, account and budget sections stops animating whole sections. | 1 | Done |
| 14 | Period sheet edits a draft | `DateRangeFilterButton` bound picks straight to the screen's range, re-running its query under the open sheet; the sheet was always full height. | Draft seeded on open, committed once on dismiss (close or swipe); `[.medium, .large]` for month and year grids, `.large` for the calendars. | Picking a period no longer rebuilds the screen behind the sheet until it closes. | 3, 4 | Done |
| 15 | Report fetches its window, searches once | `ReportContent` queried the whole ledger; highlights ran three more full searches; name dictionaries rebuilt per use. | Query from `min(previous.start, range.start)` to `range.end` (`ReportContentSpan`); one highlights search over the shared span, windows cut by date; dictionaries once per body. | Report cost scales with two periods, and text search folds each note once for highlights. | 1, 3 | Done, parity tested |
| 16 | Trip and goal list read trip rows | Trip detail summed its trip over the whole ledger in a child `init` on every parent rebuild; the goal list did the same per trip card and evaluated its snapshot up to three times. | `LedgerFetch.tripTransactions` for the trip (plus the `asOf` month for capacity), summary in `body`; goal list queries `tripWorkspaceID != nil`, groups by trip once, `let` snapshot. | Trip screens cost the trip's rows, not the ledger. | 1, 3 | Done |
| 17 | Jar and goal details read one month | `BudgetJarDetailView` and `GoalAccumulationDetailView` fetched the whole ledger for one month's figures; the jar screen searched linearly per row. | Month predicate in `init`; one lookup of categories, accounts, instruments and sales per body. | Same as 10 for these pushed screens. | 1, 3 | Done, parity tested |
| 18 | Income timeline reads one month | The timeline queried every transaction and rebuilt a revision value per row on each update. | Month list in a child with a month-scoped query and revision; backfill stays in the shell. | Timeline updates cost one month. | 3 | Done; backfill gate not done (see below) |
| 19 | Charts | `NetTrendCard` built a gradient per point and rebuilt the chart on every touch move; `AllocationDoughnut`'s `ViewThatFits` built the chart twice. | One gradient; selection stores the snapped day only when it changes; a small `Layout` places one chart beside or above the legend by ideal width. | Fewer chart rebuilds while dragging; one chart per doughnut update. Old and new doughnut renders were byte-identical at seven widths (temporary `ImageRenderer` test). | 1 | Done |
| 20 | Notification diff | Reconcile removed and re-added every MonMon request (up to 61) on each launch and foreground. | Requests carry a fingerprint in `userInfo`; only stale ones are removed and only missing ones added. | Launch and foreground stop rewriting the notification schedule. | launch | Done, unit tested |
| 21 | Dead code and tab API | `AssetGrowthCard` compiled but was used only by its preview; `.tabItem` is soft deprecated on iOS 18. | Card deleted; iPhone tab bar uses `Tab(_:systemImage:value:)` (deployment target is iOS 18.0). | Smaller build; no runtime effect expected. | none | Done; tab bar not yet seen on the device |

## Found, deliberately not changed

| Idea | Why it was left | What it would take |
|------|-----------------|--------------------|
| Commit of a swipe still does real work at release | Delete saves synchronously (`SyncWriteGate.save` also refreshes two widget snapshots), and every live `@Query` refetches. Deferring the action until the snap-back animation ends would change when the row disappears and when the editor opens, which is a behaviour change. | Measure first. If the save is the hitch, consider moving widget refresh off the critical path. |
| Per-frame swipe work | The drag offset already lives in `TransactionSwipeRow`'s own `@State`, so a frame only rebuilds that row; the card content is a stored value SwiftUI does not re-evaluate. Nothing above the row is invalidated by the drag. Gesture arbitration with the scroll view (`UIPanGestureRecognizer` delegate only implements `gestureRecognizerShouldBegin`) cannot be judged without the device. | Instruments on the iPhone while swiping. |
| Gate the income backfill on a store count | SwiftData rejects a predicate on the `TransactionKind` enum: `kind == .income` throws and `kind.rawValue == "income"` crashed the test host. Counting nil snapshots alone matches every expense. | A stored raw kind (schema change, after sync removal), or a persisted "backfilled" marker. |
| Narrow `WealthView` and `WealthAccountsSection` queries | Every account balance needs every row, so the ledger query stays; item 8 removed the per-account rescans instead. | Cached balances maintained on save. |
| `#Index` on `occurredAt`, `accountID`, `tripWorkspaceID` | Schema change, deferred until the sync removal lands. | Add after `refactor/remove-p2p-sync` merges. |
| `DateRangeFilter` calendar | `MCalendarView` (MijickCalendarView) builds a range of months for the period sheet; it is third-party. | Profile the period sheet; consider a narrower month span. |
| `TransactionFilterSheet` count per keystroke | It now fetches one period per draft change instead of filtering the whole ledger, but it still runs on every keystroke. | Debounce only if it shows up in a trace. |
| `AppLanguage.bundle(for:)` per call | Looks up the `.lproj` path for every `AppText.string`; cheap, and a cache needs a Swift 6 safe static. | Only if a trace points at it. |
| `TransactionSwipeRow.clipShape` | Rounded clip on every row. Removing it at rest would show the outer half of the card stroke that is clipped today, a visual change. | Leave. |

## How to verify on the iPhone

After the branch is merged to `dev` and installed with
`scripts/run-iphone.sh Yushaku`:

1. Record with the SwiftUI template (`.claude/skills/swiftui-expert-skill`,
   `references/trace-recording.md`) while scrolling a busy month, swiping rows
   both ways, opening and closing the details, filter, categories and editor
   sheets, and swiping them down.
2. Compare hitch counts and the `TransactionListView` / `ReportView` body
   counts against a trace of the previous `dev`.
3. For `perf/screens`: open Plan, Wealth, an account, a trip and the income
   timeline, switch segmented tabs, open and swipe down the period sheet and
   an editor, and compare `BudgetContent`, `WealthView`, `AccountDetailView`
   body counts and hitches against the previous `dev`.
