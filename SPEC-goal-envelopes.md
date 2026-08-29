# Spec: Goal Envelopes

## Objective

Add financial goals for a home, vehicle, trip, or an owner-defined purpose. A
goal earmarks money inside one budget jar and reserves a monthly contribution
from that jar's plan. It is a planning overlay: it never creates an asset,
transaction, transfer, or second balance.

Success means the owner can see what has been earmarked, what remains, the
monthly contribution required to meet a target date, and the forecast completion
date at the contribution they chose.

## Tech Stack

- Swift 6, SwiftUI, SwiftData, Swift Testing
- Existing `BudgetJar`, `BudgetSummary`, recurring income, theme, localization,
  CloudKit container, and complete backup/restore contract

## Commands

- Focused tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonGoalDerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:MonMonTests/GoalProgressTests -only-testing:MonMonTests/FinancialGoalDraftTests`
- Full tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonGoalDerivedData CODE_SIGNING_ALLOWED=NO test`
- Format lint:
  `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- Compile-only iPhoneOS check:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphoneos -derivedDataPath /tmp/MonMonGoalDerivedData CODE_SIGNING_ALLOWED=NO build`

## Project Structure

- `MonMon/Goals/` — goal persistence, drafts, pure forecasting, and SwiftUI
- `MonMonTests/Goals/` — calculation, validation, and persistence tests
- `MonMon/Budget/` — entry point and jar deletion integrity
- `MonMon/Backup/` — complete goal export, validation, and restore
- `tasks/plan.md` — dependency order and checkpoints
- `tasks/todo.md` — implementation status and product roadmap

## Behaviour and Code Style

- Goal kinds are Home, Vehicle, Trip, and Custom. The kind supplies a suggested
  name and style only; it does not change financial calculations.
- Every goal has one funding jar, a target amount, an earmarked amount, a target
  date, and a planned monthly contribution.
- Earmarked money is metadata inside the selected jar. It is never added to
  Wealth or subtracted from an account, and editing it never writes a financial
  transaction.
- Several goals may use one jar. Their monthly contributions are aggregated
  once and cannot exceed that jar's planned recurring-income allocation when a
  goal is saved.
- If income or jar percentages later reduce capacity, existing goals remain
  intact and the Goals screen shows the overcommitted amount. MonMon never
  silently edits an owner's goal.
- A custom jar cannot be deleted while any goal references it. The owner must
  move or delete those goals first. Savings and Investment remain protected by
  their existing system roles.
- Required monthly contribution is the remaining target divided across the
  monthly opportunities through the target date, rounded up to a whole đồng.
- Forecast completion uses the chosen monthly contribution. No forecast is
  shown when the contribution is zero; a completed goal reports completion now.
- Forms trim names, require positive targets, keep earmarked money between zero
  and the target, reject past target dates, require a valid jar, and reject
  negative monthly contributions.
- Lists use stable UUID identity, item-driven sheets, native controls, Dynamic
  Type, non-colour status text, and explicit VoiceOver labels.

```swift
let snapshot = GoalProgress.snapshot(
    goal: goal,
    asOf: asOf,
    calendar: calendar
)
```

## Testing Strategy

- RED/GREEN pure tests for required contribution, completion forecast, completed
  goals, zero contribution, and month-boundary behaviour.
- Draft tests for all input validation and per-jar monthly commitment capacity.
- In-memory SwiftData tests for persistence and preventing deletion of a jar
  referenced by goals.
- Backup document, validator, export, replacement restore, and legacy decode
  tests include goals.
- Full macOS tests, strict formatting, and compile-only iPhoneOS build before the
  branch is handed back.

## Boundaries

- Always: keep goal values out of net worth; use stable IDs; keep every stored
  field CloudKit-compatible; preserve complete backup/restore; localize visible
  copy; provide accessible labels and non-colour status.
- Ask first: automatically create bank transfers or savings/fund records; support
  more than one funding jar per goal; merge into `dev`; install on iPhone.
- Never: count earmarked money as a new asset; infer trip expenses from category;
  delete a jar still referenced by a goal; use a Simulator for runtime checks.

## Success Criteria

- The owner can add, edit, and delete Home, Vehicle, Trip, and Custom goals.
- Every goal shows target, earmarked, remaining, progress, required monthly
  contribution, funding jar, and forecast completion.
- Multiple goals can use one jar and their monthly money is committed only once.
- Saving a new commitment cannot exceed the selected jar's current monthly plan.
- Existing overcommitment caused by a later income/jar change is visible and is
  never silently rewritten.
- A referenced custom jar cannot be deleted.
- Goals survive complete export and authoritative restore; old backups without
  goals still decode and restore.
- Focused/full tests, format lint, and compile-only iPhoneOS build pass.

## Out of Scope

- Automatic transfers, recurring transactions, or asset purchases
- Multiple funding jars for one goal
- Goal contribution history and reminders
- Trip spending, category breakdowns, and per-transaction jar overrides
- Historical budget snapshots or rollover balances

## Open Questions

None for this slice. Trip spending remains in the `trip-workspace` module.
