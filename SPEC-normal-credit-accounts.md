# Spec: Normal and Credit Accounts

## Objective

Replace the separate Cash and Bank account choices with one Normal account type,
while preserving every existing account and its financial history. Credit
accounts gain a non-negative credit limit and show how much credit remains
available alongside the current balance.

Available credit is informational in this change. It does not increase assets or
net worth and does not block a transaction that takes a card beyond its limit.

## Tech Stack

- Swift 6, SwiftUI, and SwiftData.
- Swift Testing for value, validation, persistence, migration, and backup behavior.
- Existing MonMon theme and VND parsing/formatting; no new dependencies.

## Commands

- Test: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test`
- Lint: `rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension`
- macOS build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build`
- Non-Simulator iOS build: `rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/MonMonDeviceDerivedData CODE_SIGNING_ALLOWED=NO build`
- Physical-device validation after an approved merge to `dev` only:
  `scripts/run-iphone.sh Yushaku`

## Project Structure

- `MonMon/Accounts/CashAccountKind.swift`: canonical Normal/Credit type contract
  plus legacy Cash/Bank decoding during migration.
- `MonMon/Accounts/CashAccount.swift`: persisted credit limit.
- `MonMon/Accounts/AccountDraft.swift`: editor state and validation.
- `MonMon/Accounts/AccountEditorForm.swift`: two-choice account picker and
  credit-limit input.
- `MonMon/Accounts/CashBalanceSummary.swift`: pure available-credit calculation.
- `MonMon/Accounts/CashAccountCard.swift`: current balance and available-credit
  presentation.
- `MonMon/Backup/`: backward-compatible backup encoding, validation, and restore.
- `MonMonTests/Accounts/` and `MonMonTests/Backup/`: behavioral and compatibility
  coverage.

## Code Style

Keep financial arithmetic in Decimal-based pure helpers and let views format the
result:

```swift
static func availableCredit(limit: Decimal, currentBalance: Decimal) -> Decimal {
    max(.zero, limit + currentBalance)
}
```

Use existing theme tokens, card composition, localization, accessibility labels,
and identifiers. Do not duplicate account balance derivation in a view.

## Testing Strategy

- Start with failing tests for Normal/Credit cases, legacy `cash`/`bank` decoding,
  credit-limit validation, persistence, and available-credit arithmetic.
- Cover old backup records without a credit limit and new backup round trips with
  one.
- Run focused suites during each increment, then the full macOS suite, recursive
  format lint, macOS build, and generic iOS device build.
- Do not run a Simulator. The owner performs hands-on validation after an approved
  merge to `dev` and successful physical-device install/launch.

## Boundaries

- Always: preserve account IDs, balances, relationships, and transaction history;
  decode legacy Cash/Bank data as Normal; require a valid non-negative credit limit
  for Credit; clear the stored limit when an account becomes Normal; keep available
  credit out of asset and net-worth totals.
- Ask first: enforcing the credit limit on transactions/transfers/investments,
  changing the meaning or sign of current credit balance, or changing backup format
  version.
- Never: delete legacy account data, add dependencies, merge to `dev`/`main`, push,
  install on the iPhone from this branch, or use an iPhone Simulator.

## Success Criteria

- Add/Edit Account exposes exactly Normal and Credit.
- Existing Cash and Bank accounts appear and behave as Normal without losing data.
- New Normal accounts default to a zero credit limit and cannot retain a limit.
- Credit requires a non-negative credit limit persisted as exact VND Decimal data.
- A credit card with a 20,000,000 limit and a -5,200,000 current balance displays
  14,800,000 available credit; a balance beyond the limit displays zero.
- Available credit is shown on Credit account cards and is not included in cash,
  assets, liabilities, or net-worth calculations.
- Old backups containing `cash`/`bank` and no credit-limit field remain restorable;
  new backups encode `normal` and the credit limit.
- Focused/full tests, formatting, macOS build, and non-Simulator iOS build pass.

## Open Questions

None. Credit-limit enforcement is explicitly outside this change.
