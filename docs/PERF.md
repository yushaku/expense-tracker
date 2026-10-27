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

## Found, deliberately not changed

| Idea | Why it was left | What it would take |
|------|-----------------|--------------------|
| Commit of a swipe still does real work at release | Delete saves synchronously (`SyncWriteGate.save` also refreshes two widget snapshots), and every live `@Query` refetches. Deferring the action until the snap-back animation ends would change when the row disappears and when the editor opens, which is a behaviour change. | Measure first. If the save is the hitch, consider moving widget refresh off the critical path. |
| Per-frame swipe work | The drag offset already lives in `TransactionSwipeRow`'s own `@State`, so a frame only rebuilds that row; the card content is a stored value SwiftUI does not re-evaluate. Nothing above the row is invalidated by the drag. Gesture arbitration with the scroll view (`UIPanGestureRecognizer` delegate only implements `gestureRecognizerShouldBegin`) cannot be judged without the device. | Instruments on the iPhone while swiping. |
| Other tabs keep ledger-wide queries | `BudgetScreen`, `WealthView`, `WealthAccountsSection`, `ReportContent` (highlights compare earlier periods), `AccountDetailView` (about eleven queries), `GoalListView`, `TripDetailView`, `BudgetJarDetailView`, several editors. Every save refetches them while their tab is alive. Each needs its own analysis of which rows its figures really read. | Narrow one screen at a time, with tests that the figures do not change. |
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
