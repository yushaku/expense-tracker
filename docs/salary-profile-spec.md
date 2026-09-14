# Salary profile and calculator UX

Status: approved by the user. Implementation continues on `fix/UI`.

Resolved scope: one personal profile; persist the agreed salary and Gross/Net
basis separately from calculated take-home pay. Additional payroll items remain
outside this change until their fields and calculation rules are specified.

## Objective

Persist the user's salary calculation inputs and explicitly link the profile to
the recurring salary it updates. Replace the temporary calculator form with a
clear profile → inputs → take-home estimate → recurring salary flow.

## Proposed scope

- Add a SwiftData `SalaryProfile` entity with a stable UUID, display name, salary
  amount, Gross/Net input mode, dependant count, calculation period, insurance
  region, optional custom insurance salary, optional recurring rule UUID, and
  creation/update timestamps. Money uses `Decimal`, following existing models.
- Initially expose one personal profile unless the user requests multiple people.
  Do not create authentication, accounts for signing in, or employee management.
- Save validated profile inputs explicitly; reopening restores the saved inputs.
  Canceling edits does not change stored values.
- Present a clear Net estimate, Gross and total deductions, with a detailed
  insurance/tax breakdown. Group profile, income, dependants, and insurance fields.
- Show the linked recurring salary's amount, account, and schedule. Allow choosing
  a compatible VND monthly income rule or creating a new Salary rule.
- Applying the calculated Net opens a review step. Saving updates that specific
  rule, preserving its account, schedule and generation history. Only persist a
  new link when the recurring rule has actually saved; cancel leaves it unchanged.
- Saving profile inputs alone must not rewrite recurring amounts or historical
  transactions. Surface when the estimate and linked recurring amount differ.
- A deleted or incompatible linked rule shows an unlinked state; never silently
  fall back to the first salary rule. Existing data may be offered as a one-time
  import into the new profile, without assuming it belongs to the user.
- Include profiles and links in financial backup, restore, reset, and device sync,
  including reference remapping and compatibility with existing backups.
- Translate new UI text into Vietnamese and preserve keyboard, VoiceOver and
  Dynamic Type support. Use adaptive layouts for Mac and iPhone.

## Boundaries and open questions

- Confirm one personal profile versus multiple people before finalizing the UI.
- Confirm additional payroll items (allowances, bonuses, overtime, advances or
  other deductions). The initial proposal persists existing calculator inputs;
  it does not invent tax treatment for new items.
- Preserve the existing calculator's documented scope. Any extension to payroll
  formulas requires verified official sources and explicit calculation tests.
- Preserve confirmation, write gates, rollback, and recurring generation rules.
- Do not add dependencies, auto-merge, push, install, or run a Simulator.

## Implementation plan

1. Add the validated profile model/draft and persistence tests; register it in
   `MonMon/App/MonMonSchema.swift`.
2. Integrate backup and sync transport, validation, reference mapping, reset and
   old-backup compatibility. Verify round trips and failed-write behavior.
3. Add explicit recurring linkage and save integration. Test cancel, missing rule,
   selecting between multiple rules, and preserving schedule/history.
4. Redesign `MonMon/Settings/SalaryCalculatorView.swift` around the persisted
   profile, summary and recurring review actions; add English/Vietnamese strings.
5. Run all gates, review the SwiftUI correctness checklist, update
   `docs/salary-calculator.md`, and commit on `fix/UI` for user review.

## Project structure and style

Models and calculation logic live under `MonMon/Settings/`; recurring integration
under `MonMon/Recurring/`; transport changes under `MonMon/Backup/` and
`MonMon/Sync/`; tests under corresponding `MonMonTests/` directories.

Follow existing SwiftData defaults, private view-owned state, validated drafts,
and stable UUID references:

```swift
@State private var draft: SalaryProfileDraft
// Validate before mutating persistent records, then save through the sync gate.
try draft.apply(to: profile)
try SyncWriteGate.save(modelContext)
```

## Verification

Use the existing Swift Testing/XCTest conventions and in-memory SwiftData
containers. Cover profile validation/persistence, explicit linkage and cancel,
backup compatibility/round-trip, sync references, reset, and calculator regression.

Run sequentially from the repository root:

```sh
rtk proxy xcrun swift-format lint -r MonMon MonMonTests
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

Hands-on acceptance belongs to the user after a separately requested merge into
`dev` and physical-device install.
