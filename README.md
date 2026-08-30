# MonMon

MonMon is a private personal-finance app for iPhone and Mac, built with SwiftUI and SwiftData and themed with Catppuccin — Latte in light, Frappé in dark. It is single-owner and offline by default: every balance is derived from what was recorded, never from a hand-edited number, and the only network calls it ever makes are market-price lookups the owner asks for.

Read the docs before the code:

| Page                                                                                             | What it covers                                                                         |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `[docs/smart-note.html](docs/smart-note.html)`                                                   | Owner's guide — recording transactions, voice capture, statement import, reports       |
| `[docs/budget-and-goals.html](docs/budget-and-goals.html)`                                       | How jars split income, how goals earmark money inside them, what the app refuses to do |
| `[docs/architecture.html](docs/architecture.html)`                                               | The sixteen SwiftData models, their foreign keys, system boundaries, import flow       |
| `[docs/bank-transaction-auto-note-research.html](docs/bank-transaction-auto-note-research.html)` | Research behind automatic transaction notes                                            |

## Features

### Money in and out

- **Accounts** — cash, bank, and credit-card accounts with a VND opening balance. Only credit accounts may go negative.
- **Income and expense** — every entry names one account and, optionally, one category. The amount is always positive; direction comes from the kind.
- **Transfers** — money moved between two of the owner's own accounts. Both balances follow, total assets stay put.
- **Debts** — money borrowed and lent, with the payments against them. The account moves by exactly the principal; projected interest is shown, never counted.
- **Recurring rules** — rent, salary, a subscription, written once. The rule holds no balance: it stamps out ordinary transactions, catching up on every date that fell due, on launch and on returning to the foreground.

### Planning

- **Budget jars** — six seeded jars split income by percentage, together no more than 100%. A jar stores a percentage, never money.
- **Jar routing** — an expense follows its category's jar, or a trip's explicit override, or a fallback jar, so nothing drops out of the month's picture.
- **Income allocation snapshots** — each income keeps a frozen, versioned record of how it was split, so changing today's percentages cannot rewrite last month's payslip.
- **Goals** — a target amount earmarked _inside_ a jar, never a second asset. Progress, the required monthly figure, and the forecast date are all derived; the earmarked amount itself only changes when the owner edits it. A goal may not commit more of a jar's monthly plan than the jar has.
- **Trip workspaces** — a goal with money set aside opens a spending lens whose budget is that earmarked amount. Tagged expenses stay ordinary expenses, so spent and remaining are derived from money that already counted once.

### Wealth

- **Term deposits** (sổ tiết kiệm) — maturity dates, projected interest, an optional funding account, and withdrawals that leave the opening terms immutable.
- **Funds, ETFs, and gold** — held in units or weight against a shared instrument catalogue, showing cost basis, market value, and unrealized profit or loss.
- **Market valuation** — prices from Fmarket for open-ended funds, VNDIRECT for listed ETFs, and the shop-buy side of a vang.today quote for gold. A fetch happens when the owner asks, or when a screen opens onto a stale price — never on a timer, never in the background, and never with anything but a ticker or product code leaving the device.
- **Total assets** — counts transferred money once and holds still through borrowing, lending, and repaying.

### Capture without typing

- **Quick capture** — an App Intent and Siri phrase that parses a spoken or typed line into a transaction. A clean parse is saved outright; an incomplete one is staged for review rather than guessed at.
- **Quick-expense widget** — configurable one-tap presets on the Home Screen.
- **Bank-statement import** — a PDF shared from the bank app lands in the extension's inbox, is parsed off the main thread, reconciled against existing data, reviewed row by row, and committed in a single atomic save. Every imported row keeps a fingerprint, so re-importing the same statement cannot duplicate it.

### Reports and review

- Spending overview, category breakdown, net trend, and a transaction calendar for the chosen period.
- Search and filters across accounts, categories, and direction, with free-text matching on notes, categories, and amounts.
- Per-account detail with its own activity and spending sections.
- Per-category and per-day transaction lists reachable from any chart.

### Data, sync, and privacy

- **Optional iCloud sync** — a CloudKit mirror of the local store, off until the owner turns it on, applied after a relaunch.
- **Backup and restore** — a validated document covering every model, including jars, goals, and trips, with a confirmation step before a restore replaces what is on the device.
- **App lock** — Face ID or Touch ID with device-passcode fallback, re-locking after time in the background.
- **Language** — Vietnamese, English, or whatever the system is set to.

## Development

### Requirements

- macOS 15 or newer
- Xcode 26.6 or compatible newer version
- Swift 6
- iOS 18 or newer for an iPhone Simulator or physical iPhone

### Open the project

```sh
open MonMon.xcodeproj
```

### Build flavours

The build configuration picks the flavour, and the flavour owns every identifier
that decides where data lives. A dev install and a prod install on the same phone
share nothing.

|                    | Dev (`Debug`)                          | Prod (`Release`)                                                   |
| ------------------ | -------------------------------------- | ------------------------------------------------------------------ |
| Home screen name   | MonMon Dev                             | MonMon                                                             |
| App icon           | `AppIconDev` (DEV band)                | `AppIcon`                                                          |
| Bundle identifier  | `com.sonlv.monmon.local.yushaku`       | `com.sonlv.monmon.app`                                             |
| App group          | `group.com.sonlv.monmon.local.yushaku` | `group.com.sonlv.monmon.app`                                       |
| CloudKit container | `iCloud.monmon.dev`                    | `iCloud.monmon`                                                    |
| Push environment   | `development`                          | `development` (see `APS_ENVIRONMENT` in `Config/Release.xcconfig`) |

The dev icon is derived art, not a hand-drawn second logo. Regenerate it from
the real one with `swift scripts/make-dev-appicon.swift` whenever `AppIcon`
changes.

Those values are set in `Config/Debug.xcconfig` and `Config/Release.xcconfig`.
Everything downstream reads them: `PRODUCT_BUNDLE_IDENTIFIER` in the project, the
two `.entitlements` files, and the `Info.plist` keys `MonMonAppGroupIdentifier`
and `MonMonCloudKitContainer` that `ShareViewController` and `CloudSync` read at
runtime. Nothing hard-codes an identifier in Swift, so adding a flavour is an
xcconfig change.

A distinct bundle identifier gives each flavour its own container, which is what
separates the SwiftData store and `UserDefaults`; the app group separates the
share extension's statement inbox; the CloudKit container separates what syncs.

Build and install the dev flavour on the phone:

```sh
scripts/run-iphone.sh Yushaku
```

Build the prod flavour. The script refuses to run unless `HEAD` is a clean `main`
matching `origin/main`, archives with the `Release` configuration, and exports an
`.ipa` into `build/prod`. Pass a device name to also install and launch it:

```sh
scripts/build-prod.sh
scripts/build-prod.sh Yushaku
```

Both flavours need their App ID, app group, and CloudKit container to exist in
the developer account before signing succeeds. Xcode registers them when you add
the capability under **Signing & Capabilities** with that configuration selected;
`xcodebuild` will not create a CloudKit container on its own.

### Build

Both commands compile without signing, so neither needs a device, a signing
team, or an installed Simulator runtime.

Build the native Mac app:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
```

Build against the iPhone Simulator SDK without requiring an installed runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

### Test and format

Run the macOS unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

### Run on Mac

1. Open `MonMon.xcodeproj`.
2. Select the `MonMon` scheme.
3. Select **My Mac** as the destination.
4. Press **Command-R**.

No signing team is required for the current local Mac build.

### Run on iPhone Simulator

1. In Xcode, open **Settings > Components** and install an iOS Simulator runtime
   if no iPhone destination is available.
2. Select the `MonMon` scheme and an installed iPhone Simulator.
3. Press **Command-R**.

The Simulator runtime is only needed to launch the app. The command-line SDK build
above can compile the iOS target without it.

### Run on a physical iPhone

1. Sign in under **Xcode > Settings > Accounts**.
2. Select the `MonMon` target, open **Signing & Capabilities**, and choose your
   development team.
3. Connect and trust the iPhone, enable Developer Mode when prompted, and select
   the phone as the run destination.
4. Press **Command-R**.

Signing identities, provisioning profiles, and Xcode user state must remain local
and are excluded by `.gitignore`.
