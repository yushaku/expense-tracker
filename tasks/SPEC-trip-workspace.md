# Spec: Trip Workspace

## Objective

Turn a fully funded Trip goal into a spending workspace without creating a
second balance or a synthetic transfer. The owner keeps recording ordinary
expense transactions against real cash accounts and categories, while each
trip can explain its total budget, spending, remaining amount, and category
breakdown.

The lifecycle is `Saving goal -> Ready to spend -> Active trip -> Completed
trip`. The existing `FinancialGoal` owns the saving phase. A `TripWorkspace`
starts the spending phase only after a Trip goal is fully earmarked.

## Tech Stack

- Swift 6, SwiftUI, SwiftData, Swift Testing
- Existing `FinancialGoal`, `MoneyTransaction`, `BudgetJar`, category routing,
  complete backup/restore, and CloudKit-compatible schema
- No new dependency and no new ledger, account, transfer, or asset balance

## Commands

- Focused tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonTripWorkspaceDerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:MonMonTests/TripWorkspaceTests -only-testing:MonMonTests/TripSummaryTests -only-testing:MonMonTests/BudgetSummaryTests`
- Full tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonTripWorkspaceDerivedData CODE_SIGNING_ALLOWED=NO test`
- Format lint:
  `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- Compile-only iPhoneOS check:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/MonMonTripWorkspaceIOSDerivedData CODE_SIGNING_ALLOWED=NO build`

## Project Structure

- `MonMon/Trips/` — workspace model, lifecycle validation, summaries, and UI
- `MonMonTests/Trips/` — pure logic and in-memory SwiftData integration tests
- `MonMon/Transactions/` — optional trip and jar-override metadata
- `MonMon/Budget/` — override-first expense routing and jar deletion integrity
- `MonMon/Goals/` — entry from fully funded Trip goals
- `MonMon/Backup/` — optional legacy-compatible records, validation, export,
  restore, and recovery

## Data Contract

`TripWorkspace` is a normalized one-to-many parent of transactions through UUID
references, matching the repository's CloudKit-safe relationship style.

- `id: UUID` — stable workspace identity
- `sourceGoalID: UUID?` — origin goal; optional so restored or deleted goals do
  not erase trip history
- `name`, `symbolName`, `colorName` — frozen presentation from the goal
- `budgetAmount: Decimal` — frozen funded amount when spending starts
- `fundingJarID: UUID?` — default budget source and historical routing context
- `status: active | completed`
- `startedAt`, `completedAt?`, `createdAt`

`MoneyTransaction` adds:

- `tripWorkspaceID: UUID?` — at most one trip per transaction
- `budgetJarOverrideID: UUID?` — trip-specific routing before the category's
  default jar

Spent, remaining, and category totals are always derived from linked expense
transactions. They are never persisted as another balance.

## Behaviour and Code Style

- Only a fully funded `FinancialGoalKind.trip` can start a workspace, and one
  source goal can start at most one workspace.
- Starting freezes the goal's target amount and presentation. It does not move
  money or mutate any account.
- A linked transaction keeps its real account and category. Income cannot be
  attached to a trip.
- Selecting a trip defaults its jar override to the trip's funding jar. The
  owner may use category routing instead or select another current jar.
- Budget expense routing order is: valid transaction override, valid category
  mapping, then the existing fallback jar.
- Active trips accept new expenses. Existing transactions in completed trips
  remain editable for corrections, and their derived summary updates.
- Completing a trip archives it and reports the unused amount as released. It
  does not create a refund or transfer. Reopening is allowed for corrections.
- A workspace with linked transactions cannot be deleted; an empty active
  workspace can be cancelled. Deleting a workspace never deletes transactions.
- A jar referenced by a workspace cannot be deleted, preventing historical
  routing from silently changing before monthly snapshots exist.
- Trip details show budget, spent, remaining/over-budget, category breakdown,
  and linked transactions newest first.
- Fully funded Trip goals expose Start spending/Open trip actions. Trips also
  remain reachable from a dedicated list if the source goal later disappears.

```swift
let summary = TripSummary.snapshot(
    workspace: workspace,
    transactions: transactions,
    categories: categories
)
// summary.spentAmount is derived from real linked expenses only.
```

## Testing Strategy

- Pure tests cover start eligibility, one-workspace-per-goal, completion,
  reopening, exact remaining/over-budget math, and category breakdown.
- Persistence tests cover optional CloudKit-safe defaults and UUID references.
- Transaction tests cover attach/detach, income exclusion, edit direction,
  delete/undo preservation, and default/explicit jar override.
- Budget tests prove override-first routing without changing account totals.
- Store integrity tests cover duplicate reconciliation, empty cancellation,
  linked-workspace deletion prevention, and jar deletion protection.
- Backup tests cover legacy absence, validation, deterministic export,
  authoritative restore, recovery, and dangling optional references.
- Full macOS tests, strict format lint, and compile-only iPhoneOS build are
  gates. Runtime UI validation uses the physical iPhone only after merge into
  `dev`; no Simulator is used.

## Boundaries

- Always: derive spending from expense transactions; preserve ordinary
  categories; keep monetary values as `Decimal`; validate UUID references;
  preserve legacy backups and CloudKit compatibility.
- Ask first: create real transfers, liquidate Savings/Funds, auto-import travel
  bookings, add shared/group trips, or change Goal contribution math.
- Never: count a workspace as an asset; subtract spending twice; attach income;
  delete linked financial records with a workspace; silently rewrite category
  or account history; use an iPhone Simulator.

## Success Criteria

- A fully funded Trip goal can start exactly one active workspace.
- The owner can attach real expenses while retaining food, accommodation,
  transport, and other ordinary categories.
- Trip budget, spent, remaining, and category breakdown reconcile exactly to
  linked expenses.
- Trip expenses use an explicit jar override when chosen and otherwise retain
  normal category/fallback routing.
- Completing or reopening a trip changes only workspace state, not ledger data.
- Empty cancellation and protected deletion rules cannot orphan transactions or
  silently change historical routing.
- Trip models and transaction metadata survive complete backup/restore, while
  old backups still validate.
- Accessible English/Vietnamese UI exposes ready, active, and completed trips.
- Focused/full tests, review, strict lint, and compile-only iPhoneOS build pass.

## Open Questions

None for this slice. Real fund liquidation, shared trips, itinerary planning,
and receipt/media storage remain separate features.
