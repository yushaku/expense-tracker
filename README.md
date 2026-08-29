# MonMon

MonMon is a private personal-finance app for iPhone and Mac, themed with
Catppuccin — Latte in light, Frappé in dark. It has nine slices today.
`cash-balance` lets one owner add, edit, and delete local cash, bank, and credit
card accounts with a VND opening balance. `savings-deposit` adds term
deposits (sổ tiết kiệm) with maturity dates, projected interest, and an optional
funding account, plus a total-assets figure that counts transferred money only
once. `fund-etf-holdings` adds fund certificates (chứng chỉ quỹ) and ETFs held in
units, valued at a hand-entered NAV, showing cost basis, market value, and
unrealized profit or loss. `income-expense` records money in and out against one
account each, grouped by categories the owner manages, so every balance follows
what was recorded rather than a hand-edited number. `account-transfer` moves
money between two of the owner's own accounts, so both balances follow and total
assets stay put. `debt-tracking` records money borrowed and money lent out, with
the payments against them: the account moves by exactly the principal, what is
outstanding follows the payments, and total assets stay put through all of it.
`market-valuation` replaces the hand-typed NAV with one fetched from Fmarket for
open-ended funds and VNDIRECT for listed ETFs, and values physical gold from the
shop-buy side of a vang.today quote. The price lives on a `FundInstrument`
catalogue so one catalogue code can only ever carry one price. A fetch happens
when the owner asks for one, or when a screen opens onto a price older than the
day it should carry — never on a timer and never in the background. `recurring-transactions` records money that comes back — rent,
salary, a subscription — from a rule the owner writes once, catching up on
every date it has fallen due each time the app is opened.

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

## Build flavours

The build configuration picks the flavour, and the flavour owns every identifier
that decides where data lives. A dev install and a prod install on the same phone
share nothing.

| | Dev (`Debug`) | Prod (`Release`) |
| --- | --- | --- |
| Home screen name | MonMon Dev | MonMon |
| App icon | `AppIconDev` (DEV band) | `AppIcon` |
| Bundle identifier | `com.sonlv.monmon.local.yushaku` | `com.sonlv.monmon.app` |
| App group | `group.com.sonlv.monmon.local.yushaku` | `group.com.sonlv.monmon.app` |
| CloudKit container | `iCloud.monmon.dev` | `iCloud.monmon` |
| Push environment | `development` | `development` (see `APS_ENVIRONMENT` in `Config/Release.xcconfig`) |

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
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
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
