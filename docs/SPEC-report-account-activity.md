# Report monthly overview and account activity

## Objective

Keep the Report overview anchored to one selected month while the existing
report query continues to drive charts, structured filters, and search results.
Add a monthly expense breakdown by cash account. Selecting an account opens an
all-time activity timeline containing ordinary income/expense transactions and
internal transfers touching that account.

## Tech stack

- Swift 6, SwiftUI, SwiftData
- Swift Testing in `MonMonTests`
- Existing `MoneyTransaction`, `AccountTransfer`, `TransactionRange`, and
  Catppuccin-based MonMon design components

## Commands

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

Feature-branch verification stops after unit tests and format lint. Building,
installing, or launching on `Yushaku` happens only when this work is merged into
`dev`.

## Project structure and code style

- Pure monthly account aggregation and activity ordering live beside the
  transaction domain in `MonMon/Transactions`.
- SwiftUI section and detail views live in `MonMon/Transactions` and receive
  computed presentation input rather than duplicating accounting rules.
- Unit tests live in `MonMonTests/Transactions` and use deterministic dates and
  identifiers.
- Follow existing value-type summaries and explicit names, for example:

```swift
let rows = AccountSpendingSummary.rows(
    accounts: accounts,
    transactions: monthlyTransactions
)
```

## Testing strategy

- Unit coverage for expense-only account aggregation, zero-spend omission,
  deterministic ordering, account activity inclusion, and newest-first order.
- Reuse existing transaction/transfer summary suites as regression coverage.
- Run the focused transaction suites before the available full macOS suite.
- Do not use an iPhone Simulator or deploy to the physical iPhone on this branch.

## Boundaries

- Always: use the selected summary month for overview and account spending;
  preserve the independent report query; exclude income and internal transfers
  from account expense totals; include both sides of transfers in account detail.
- Ask first: changing transaction/transfer persistence, adding edit/delete
  actions to the account activity screen, or changing the existing report query.
- Never: count transfers as spending, add a dependency, rewrite unrelated account
  screens, or build/install/launch on `Yushaku` before merge into `dev`.

## Success criteria

- Report overview defaults to the current month and follows the month rail.
- Charts, report filters, and search results retain their existing query period.
- Monthly account rows include only accounts with expense, sorted by expense
  descending with deterministic ties.
- Selecting an account opens every all-time income/expense transaction for that
  account and every incoming/outgoing internal transfer, newest first.
- The existing rule that Report transaction rows appear only for text search is
  unchanged.

## Open questions

None. The owner approved the behavior above.
