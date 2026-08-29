# Spec: Budget Core

## Objective

Add a Budget destination that answers: “How much can I still spend this month
without disrupting my plan?” MonMon starts with the standard six financial jars,
lets the owner map expense categories to jars and customise the jar set, and
compares forecast income with money actually received and used.

Success means the owner can open Budget and see planned allocation, actual
allocation, used amount, and remaining amount for every jar without re-entering
salary data already stored as recurring income.

## Tech Stack

- Swift 6, SwiftUI, SwiftData, Swift Testing
- Existing `RecurringRule`, `MoneyTransaction`, `SavingsDeposit`, `FundHolding`,
  and `TransactionCategory` models
- Existing MonMon theme, localization catalogue, backup document, and CloudKit
  model container

## Commands

- Focused test:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonBudgetDerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:MonMonTests/BudgetSummaryTests`
- Full test:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonBudgetDerivedData CODE_SIGNING_ALLOWED=NO test`
- Format lint:
  `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- Compile-only iOS check:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphoneos -derivedDataPath /tmp/MonMonBudgetDerivedData CODE_SIGNING_ALLOWED=NO build`

## Project Structure

- `MonMon/Budget/` — jar persistence, seeding, pure calculations, and SwiftUI
- `MonMonTests/Budget/` — pure calculation, seed, validation, and persistence tests
- `MonMon/Backup/` — complete export/restore support for budget records
- `tasks/budget-plan.md` — dependency order and verification checkpoints
- `tasks/todo.md` — product roadmap and branch task status

## Behaviour and Code Style

- Six fixed-ID defaults total 100%: Necessities 55%, Investment 10%, Education
  10%, Savings 10%, Play 10%, Giving 5%.
- Savings and Investment carry system roles. They may be renamed or resized but
  cannot be deleted. Their role is identity-based, not name-based.
- Custom jars may be added, edited, and deleted. Allocation may be below 100%
  while the owner is reconfiguring, but may never exceed 100%.
- Every expense category has a configurable jar assignment. Seeded everyday
  categories default to Necessities; Entertainment defaults to Play. New or
  unmapped expense categories fall back visibly to Necessities until assigned.
- Planned income is the sum of active recurring income occurrences in the
  selected month. Actual income is the sum of income transactions in that month.
- Available income combines income received through today with recurring income
  still scheduled later in the month. Planned and actual income are allocated
  using the current jar percentages, so an actual bonus is distributed automatically.
- Ordinary spending follows the transaction category’s jar assignment. Savings
  principal opened in the month always uses Savings. Fund and gold purchase cost
  basis in the month always uses Investment.
- Keep calculations pure and parameterised by month/calendar; views only render
  prepared values.

```swift
let snapshot = BudgetSummary.snapshot(
    monthContaining: asOf,
    asOf: asOf,
    jars: jars,
    categories: categories,
    recurringRules: rules,
    transactions: transactions,
    savingsDeposits: deposits,
    fundHoldings: holdings
)
```

## Testing Strategy

- RED/GREEN unit tests for recurring forecast, actual-income redistribution,
  category spending, fixed Savings/Investment routing, and remaining amounts.
- In-memory SwiftData tests for one-time default seeding, role protection, and
  persisted category assignments.
- Extend backup round-trip/restore tests so budget data remains part of the
  complete snapshot contract.
- Full macOS suite, strict formatting, and compile-only physical-device SDK build
  before commit. Runtime installation remains blocked until merge into `dev`.

## Boundaries

- Always: preserve current balances; use stable IDs; keep every new stored field
  CloudKit-compatible; maintain complete backup/restore coverage; provide
  accessible labels and non-colour status text.
- Ask first: change the six default percentages; introduce actual bank transfers;
  connect an external institution; merge into `dev`; install on iPhone.
- Never: duplicate recurring income in a separate profile; infer trip membership
  from category; delete the Savings or Investment system roles; use a Simulator
  for runtime validation.

## Success Criteria

- An empty store gains exactly six default jars totalling 100%.
- Budget appears as a root destination and shows current-month plan versus actual.
- Editing income transactions immediately changes actual allocation.
- Expense categories can be reassigned and calculations follow the persisted map.
- Savings and Investment cannot be deleted; custom jars support add/edit/delete.
- Savings deposits and Gold/Fund purchases route to their fixed system jars.
- Budget records survive export and authoritative restore.
- Focused/full tests, format lint, and non-Simulator iOS build pass.

## Out of Scope

- Historical budget snapshots and rollover rules
- Goal contributions, target dates, and progress forecasting
- Trip workspaces and per-transaction jar overrides
- Automatic rebalancing advice or notifications
- Moving real money between accounts or connecting to a bank

## Open Questions

None for `budget-core`. Later modules retain their questions in `tasks/todo.md`.
