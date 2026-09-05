# MonMon

MonMon is a private personal-finance app for iPhone and Mac, built with SwiftUI and SwiftData and themed with Catppuccin — Latte in light, Frappé in dark. It is single-owner and offline by default: every balance is derived from what was recorded, never from a hand-edited number, and the only network calls it ever makes are market-price lookups the owner asks for.

| Page                                                                                             | What it covers                                                                         |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `[docs/smart-note.html](docs/smart-note.html)`                                                   | Owner's guide — recording transactions, voice capture, statement import, reports       |
| `[docs/budget-and-goals.html](docs/budget-and-goals.html)`                                       | How jars split income, how goals earmark money inside them, what the app refuses to do |
| `[docs/accounts.html](docs/accounts.html)`                                                       | Accounts — derived balances, asset allocation, net worth, twelve-month history         |
| `[docs/savings.html](docs/savings.html)`                                                         | Term deposits — simple interest, the three states, withdrawals as records              |
| `[docs/funds.html](docs/funds.html)`                                                             | Funds, ETFs and gold — immutable lots, sales, market pricing, catalogue import         |
| `[docs/architecture.html](docs/architecture.html)`                                               | The sixteen SwiftData models, their foreign keys, system boundaries, import flow       |
| `[docs/mcp.md](docs/mcp.md)`                                                                     | Read-only AI access, tool contract, privacy boundary, and client setup                 |
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
- **Goals** — a target amount earmarked _inside_ a jar, never a second asset. Progress, the required monthly figure, and the forecast date are all derived; the earmarked amount itself only changes when the owner edits it. A goal may not commit more than the jar's current-month projected capacity.
- **Trip workspaces** — a goal with money set aside opens a spending lens whose budget is that earmarked amount. Tagged expenses stay ordinary expenses, so spent and remaining are derived from money that already counted once.

### Wealth

- **Term deposits** (sổ tiết kiệm) — maturity dates, projected interest, an optional funding account, and withdrawals that leave the opening terms immutable.
- **Funds, ETFs, and gold** — held in units or weight against a shared instrument catalogue, showing cost basis, market value, and unrealized profit or loss. Gold is valued at the shop-buy quote, while any fee or deduction actually charged on sale reduces the cash proceeds and realized PnL of that sale.
- **Coins** — held against the same catalogue, priced by CoinGecko in đồng. A purchase or a sale may be typed in dollars at a rate the owner states, which is converted once on the way in: what is stored is đồng, and each record keeps the rate that got it there.
- **Coin swaps** — one coin exchanged for another, which is how most coin trading happens and touches no bank account. Recorded as a disposal of what was given and a new lot in what was received, settled at one value so the trade can neither create nor lose value. The coin given up settles its gain; the coin received starts at what it cost.
- **Market valuation** — prices from Fmarket for open-ended funds, VNDIRECT for listed ETFs, the shop-buy side of a vang.today quote for gold, and CoinGecko for coins. A fetch happens when the owner asks, or when a screen opens onto a stale price — never on a timer, never in the background, and never with anything but a ticker, a product code or a coin identifier leaving the device.
- **Instrument catalogue imports** — add open-ended funds from Fmarket, HOSE-listed ETFs from VNDIRECT, gold products from vang.today, or coins from CoinGecko. ETF rows are saved only after VNDIRECT returns a valid closing price; an unavailable ticker does not block the rest of the selection.
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
- **Optional read-only AI access on Mac** — an embedded local MCP helper exposes raw records from an App Group SQLite snapshot to Codex or Claude Desktop after explicit consent. The helper has no CloudKit entitlement or write tools.
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

Build, install, and launch either flavour on this Mac. The script installs into
`~/Applications`, so it does not need administrator privileges:

```sh
scripts/install-mac.sh dev
scripts/install-mac.sh prod # clean main matching origin/main only
```

The installed apps are `~/Applications/MonMon Dev.app` and
`~/Applications/MonMon.app`. Override the destination with
`MONMON_MAC_INSTALL_DIR` when needed.

Build and install the dev flavour on an iPhone:

```sh
scripts/run-iphone.sh Yushaku
```

Build and install Prod on an iPhone (clean `main` only):

```sh
scripts/build-prod.sh
scripts/install-prod.sh Yushaku
```

### Add a new phone (prod)

Prod is development-signed, so the phone must be on the team before install works.

1. Unlock the phone, plug in USB, tap **Trust**.
2. Enable **Settings → Privacy & Security → Developer Mode**, then restart.
3. Confirm the Mac sees it: `xcrun devicectl list devices`
4. First install registers the UDID automatically (`-allowProvisioningDeviceRegistration`). Or add it by hand in [developer.apple.com](https://developer.apple.com/account/resources/devices/list) → Devices.
5. `scripts/install-prod.sh "<Device Name>"`
6. On the phone: **Settings → General → VPN & Device Management** → trust the developer certificate.

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

### Date display

In Settings → Date format, choose `dd/MM/yyyy` (default),
`MM/dd/yyyy`, or `yyyy-MM-dd`. The choice is saved on this device and applies
immediately, independently of the interface language. Each option shows a sample
date, and the selected option has a checkmark. Date-time labels retain
the localized time, and month/year headings retain their existing labels.
Backup files, bank imports, and API date encodings keep their existing formats.
