# MonMon

MonMon is a private personal-finance app for iPhone and Mac. It has two slices
today. `cash-balance` lets one owner add local cash or bank accounts with a VND
opening balance. `savings-deposit` adds term deposits (sổ tiết kiệm) with
maturity dates, projected interest, and an optional funding account, plus a
total-assets figure that counts transferred money only once.

## Requirements

- macOS 15 or newer
- Xcode 26.6 or compatible newer version
- Swift 6
- iOS 18 or newer for an iPhone Simulator or physical iPhone

## Open the project

```sh
rtk open MonMon.xcodeproj
```

Use the shared `MonMon` scheme in Xcode.

## Build

Build the native Mac app:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
```

Build against the iPhone Simulator SDK without requiring an installed runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

## Test and format

Run the macOS unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests
```

## Run on Mac

1. Open `MonMon.xcodeproj`.
2. Select the `MonMon` scheme.
3. Select **My Mac** as the destination.
4. Press **Command-R**.

No signing team is required for the current local Mac build.

## Run on iPhone Simulator

1. In Xcode, open **Settings > Components** and install an iOS Simulator runtime
   if no iPhone destination is available.
2. Select the `MonMon` scheme and an installed iPhone Simulator.
3. Press **Command-R**.

The Simulator runtime is only needed to launch the app. The command-line SDK build
above can compile the iOS target without it.

## Run on a physical iPhone

1. Sign in under **Xcode > Settings > Accounts**.
2. Select the `MonMon` target, open **Signing & Capabilities**, and choose your
   development team.
3. Connect and trust the iPhone, enable Developer Mode when prompted, and select
   the phone as the run destination.
4. Press **Command-R**.

Signing identities, provisioning profiles, and Xcode user state must remain local
and are excluded by `.gitignore`.

## Current scope

- Included: add and list local cash/bank accounts; add, edit, and delete savings
  deposits with simple interest paid at maturity; an optional funding link that
  lowers an account's available balance without touching its opening balance; VND
  validation and formatting, exact `Decimal` totals, on-device SwiftData
  persistence, and shared SwiftUI UI.
- Owner validation: form behavior, interest against a hand calculation, relaunch
  persistence, iPhone Dynamic Type and keyboard, and Mac window resizing.
- Not included yet: transactions, editing or deleting cash accounts, interest paid
  on a schedule, rollover or early withdrawal, iCloud, market-priced investments,
  network access, AI, or MCP.

## Architecture

- One multiplatform app target shares SwiftUI source between iOS and macOS.
- SwiftData stores `CashAccount` records locally; `@Query` drives the visible
  account list and combined total.
- `AccountDraft` and `SavingsDraft` validate external text before any model is
  inserted or mutated, and money uses `Decimal` throughout.
- A savings deposit stores its funding account's `id`; available balances and
  total assets are derived, so deleting a deposit needs no compensating write.
- The approved boundaries and verification contracts live in
  `SPEC-cash-balance.md` and `SPEC-savings-deposit.md`.
