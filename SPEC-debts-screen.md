# Spec: Dedicated Debts Screen

## Objective

Move debt records and debt-management actions out of `WealthView` into the
existing dedicated `DebtListView`. Wealth remains a summary and shows only the
current outstanding amount borrowed and the current outstanding amount lent.
The summary opens the Debts screen, where the owner can browse debts, add a
debt, open a debt, and manage its payments.

## Tech Stack

- Swift 6 and SwiftUI for navigation and presentation.
- SwiftData `@Query` for debts, payments, and accounts.
- Swift Testing for financial summary behavior.
- Existing MonMon theme, card, editor, and detail components; no dependency or
  schema changes.

## Commands

- Test: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- Lint: `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- Build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build`
- Physical-device validation after an approved merge to `dev` only:
  `scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/Accounts/WealthView.swift`: the Wealth summary and entry point to
  Debts.
- `MonMon/Debts/DebtListView.swift`: the dedicated debt-management screen.
- `MonMon/Debts/DebtDetailView.swift`: one debt and its payments.
- `MonMon/Debts/DebtSummary.swift`: canonical outstanding-balance calculations.
- `MonMonTests/Debts/`: debt calculation and persistence tests.

## Code Style

Use destination-based links for pushed screens, matching the reliable
navigation pattern already used by Wealth:

```swift
NavigationLink {
    DebtListView()
} label: {
    debtSummaryCard
}
.buttonStyle(.plain)
```

Keep financial calculations in `DebtSummary`, use theme tokens rather than new
raw colours or dimensions, and give every interactive element a clear
accessibility label, identifier, and hint.

## Testing Strategy

- Retain `DebtSummary.totalOutstanding` as the single source for both Wealth
  totals and cover its direction/payment behavior with existing unit tests.
- Compile the navigation and toolbar changes through the full macOS test suite.
- Run recursive format lint and a non-Simulator Debug build.
- After the branch is reviewed and merged into `dev`, the owner validates on the
  physical iPhone that the Wealth summary opens Debts and that add/detail flows
  remain usable. No Simulator runtime validation.

## Boundaries

- Always: show outstanding balances after payments, preserve add/detail/payment
  flows on the Debts screen, and keep Wealth limited to the two requested debt
  figures.
- Ask first: changing the debt data model, calculation semantics, editor fields,
  or whether DebtList should be modal instead of pushed.
- Never: delete debt data, add dependencies, merge to `dev`/`main`, push, or run
  the app on a physical device before explicit approval.

## Success Criteria

- Wealth shows no individual debt cards and no add-debt control.
- Wealth shows exactly two debt values: total outstanding borrowed and total
  outstanding lent, including zero values when a direction has no open balance.
- The Wealth debt summary is one accessible navigation target that pushes a
  screen titled “Debts”.
- The Debts screen shows the existing net position, grouped debt records, empty
  states, and add-debt action.
- A debt row opens `DebtDetailView`, and existing edit/payment flows remain
  available.
- Full macOS tests, Swift format lint, and non-Simulator Debug build pass.

## Open Questions

None. The summary will be one card containing the two requested values, and the
Debts screen will be pushed within Wealth's existing navigation stack.
