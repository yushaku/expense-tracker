# Spec: Income Allocation Timeline

## Objective

Explain how every recorded income transaction was divided across the owner's
budget jars. Salary generated from a recurring rule, imported income, and
one-off income all use the same snapshot contract.

An allocation snapshot is explanatory metadata attached to the income
transaction. It never moves money, creates a transfer, changes an account
balance, or adds another asset. New income captures the jar configuration at
the time it is recorded. Existing income without a snapshot is captured once
when the timeline first encounters it and is visibly marked as estimated.

Success means the owner can choose a month, open each income event, and
reconcile its full amount across frozen jar allocations plus any unallocated
remainder. Later jar edits must not rewrite that history.

## Tech Stack

- Swift 6, SwiftUI, SwiftData, Swift Testing
- Existing `MoneyTransaction`, `BudgetJar`, recurring generation, statement
  import, transaction capture, localization, complete backup, and CloudKit
  store
- No new dependency and no new financial ledger model

## Commands

- Focused tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonIncomeTimelineDerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:MonMonTests/IncomeAllocationSnapshotTests -only-testing:MonMonTests/IncomeAllocationLifecycleTests -only-testing:MonMonTests/IncomeAllocationTimelineTests`
- Full tests:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonIncomeTimelineDerivedData CODE_SIGNING_ALLOWED=NO test`
- Format lint:
  `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- Compile-only iPhoneOS check:
  `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/MonMonIncomeTimelineIOSDerivedData CODE_SIGNING_ALLOWED=NO build`

## Project Structure

- `MonMon/IncomeAllocation/` — snapshot codec, capture/backfill policy, timeline
  preparation, and SwiftUI
- `MonMonTests/IncomeAllocation/` — pure allocation, persistence, integration,
  and backfill tests
- `MonMon/Transactions/` — optional snapshot field and manual edit lifecycle
- `MonMon/Recurring/` and `MonMon/Imports/` — capture at automatic creation
  boundaries
- `MonMon/Backup/` — optional snapshot field validation, export, and restore
- `tasks/plan.md` and `tasks/todo.md` — implementation state

## Behaviour and Code Style

- Store one optional, versioned JSON snapshot string on `MoneyTransaction`.
  Optional storage keeps the SwiftData model CloudKit-compatible and lets old
  transactions load before backfill.
- A snapshot stores the source amount, capture timestamp, estimated flag, and
  frozen slices. Each slice keeps jar UUID, name, symbol, colour, percentage,
  and exact allocated amount, so later rename or deletion cannot erase history.
- Allocated slice amounts plus the unallocated remainder equal the source
  transaction exactly. Whole-dong corrections use the largest fractional
  remainder, with stable UUID tie-breaking.
- New income captures the current jars in manual entry, recurring generation,
  statement import, and pending-capture commit paths.
- An edit from expense to income captures the current jars. Editing an existing
  income amount recalculates exact amounts with its frozen percentages and
  historic presentation. Editing income into expense removes the snapshot.
- Delete and undo preserve the embedded snapshot with the transaction.
- Backfill touches only recorded income whose snapshot is absent. It is
  idempotent and marks those snapshots as estimated; malformed non-nil
  snapshots are reported rather than silently overwritten.
- The timeline contains recorded income only. Future recurring occurrences
  remain a Budget forecast and are not mixed into historical events.
- The timeline is month-selectable, newest event first, and identifies events
  as recurring, imported, or one-off from existing provenance.
- Budget's live plan remains based on the current jar configuration. The
  timeline explicitly says its historical splits can differ after setup edits;
  historical monthly Budget snapshots remain a separate roadmap item.

```swift
let snapshot = IncomeAllocationSnapshot.capture(
    amount: transaction.amount,
    jars: jars,
    capturedAt: now,
    isEstimated: false
)
transaction.incomeAllocationSnapshot = try IncomeAllocationSnapshotCodec.encode(snapshot)
```

## Testing Strategy

- Pure tests cover exact reconciliation, partial allocation, deterministic
  rounding, frozen jar presentation, and recalculation after an amount edit.
- In-memory SwiftData tests cover idempotent legacy backfill, expense exclusion,
  malformed snapshot preservation, and delete/undo round trips.
- Integration tests cover manual entry, recurring generation, imported income,
  and pending-capture creation boundaries.
- Backup tests cover optional legacy decode/checksum, snapshot validation,
  export, authoritative restore, and malformed untrusted JSON.
- Full macOS tests, strict formatting, and compile-only iPhoneOS build are gates.
  Runtime validation uses the physical iPhone only after the branch is merged
  into `dev`; no Simulator is used.

## Boundaries

- Always: preserve exact transaction amount; freeze captured percentages and
  labels; mark backfilled history estimated; validate backup snapshots before
  writes; keep snapshot lifecycle aligned with transaction lifecycle.
- Ask first: use allocation history to change Budget totals; create transfers;
  add future projected events; merge into `dev`; install on iPhone.
- Never: rewrite a valid historic snapshot after jar edits; count snapshot
  amounts as new money; overwrite malformed non-nil history silently; use an
  iPhone Simulator.

## Success Criteria

- Every newly recorded income source captures one valid frozen allocation.
- Existing income is backfilled once and visibly marked estimated.
- An event's slices and unallocated remainder equal its transaction amount.
- Jar rename, resize, or deletion does not change a captured event.
- Editing an income amount keeps its captured percentages; changing direction
  creates or removes snapshot metadata correctly.
- The owner can browse months and distinguish recurring, imported, and one-off
  income events with accessible English and Vietnamese UI.
- Goal, Wealth, account, transaction, and Budget ledger totals are unchanged by
  the snapshot feature.
- Complete backup/restore preserves snapshots and old backups still validate.
- Focused/full tests, review, strict format lint, and compile-only iPhoneOS build
  pass.

## Open Questions

None for this slice. Future projected events and historical monthly Budget
snapshots remain separate roadmap work.
