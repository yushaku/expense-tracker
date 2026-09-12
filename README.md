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

- **Natural-language entry** — type a sentence in Add Transaction to fill the form before saving. The Record Transaction Siri shortcut saves a clean parse directly and stages incomplete entries for review.
- **Quick-expense widget** — configurable one-tap presets on the Home Screen.
- **Bank-statement import** — a PDF shared from the bank app lands in the extension's inbox and is parsed off the main thread. Valid new rows are checked by default. Invalid rows appear first, unchecked, with a reason; uncheck any row to leave it out, or tap its details to edit category and note. Import creates income/expense transactions only, without reconciling account balances or statement totals. The selected rows are committed in one atomic save. If validation fails at save time, affected rows move to Needs attention with a reason and are unchecked; the remaining valid selections can be retried. A storage failure keeps selections and explicitly reports that nothing was saved. Existing import fingerprints prevent duplicates when the same report is imported again.

### Reports and review

- Spending overview, category breakdown, net trend, and a transaction calendar for the chosen period.
- Search and filters across accounts, categories, and direction, with free-text matching on notes, categories, and amounts.
- Per-account detail with its own activity and spending sections.
- Per-category and per-day transaction lists reachable from any chart.

### Data, sync, and privacy

- **Local first** — data stays on your devices. Optional, manually initiated P2P sync connects one iPhone–Mac pair on the same local network. No account, cloud storage, or relay server.
- **Optional read-only AI access on Mac** — an embedded local MCP helper exposes raw records from an App Group SQLite snapshot to Codex or Claude Desktop after explicit consent. The helper has no write tools.
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

From `dev`, build, install, and launch the dev flavour on both a physical iPhone
and this Mac with one command:

```sh
scripts/run-iphone.sh Yushaku
```

The iPhone must be connected, unlocked, and have Developer Mode enabled. The
script installs on the iPhone first, then calls `scripts/install-mac.sh dev`.
Builds run sequentially using the workspace cache. If a step fails, the script
stops and does not report both devices as installed. Mac installation still
supports `MONMON_MAC_INSTALL_DIR` and `MONMON_MAC_DERIVED_DATA_PATH` overrides.

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

Both flavours need their App ID and app group to exist in the developer account
before signing succeeds. Xcode registers them when you add the capability under
**Signing & Capabilities** with that configuration selected.

### Build

Run the commands below from the repository root. All build/test commands and
install scripts share `build/DerivedData/` inside this workspace. It retains
compiled intermediates, package checkouts, and test results between runs; `build/`
is ignored by Git. Keep this directory to reuse the cache. After deleting it,
the next build recreates it and takes longer. Xcode separates products by SDK
and configuration within this directory; run builds/tests sequentially.

Scripts resolve this default relative to their project root, even when invoked
from another directory. `MONMON_DERIVED_DATA_PATH` overrides the shared script
cache; `MONMON_MAC_DERIVED_DATA_PATH` and `MONMON_PROD_DERIVED_DATA_PATH` take
precedence for their respective scripts. For direct `xcodebuild` commands, use
`-derivedDataPath build/DerivedData` as shown below.

Both commands compile without signing, so neither needs a device, a signing
team, or an installed Simulator runtime.

Build the native Mac app:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Build against the iPhone Simulator SDK without requiring an installed runtime:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -sdk iphonesimulator -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
```

### Test and format

Run the macOS unit and in-memory persistence tests:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Check Swift formatting:

```sh
rtk swift format lint --strict --recursive MonMon MonMonTests MonMonShareExtension
```

### Adding transactions

Add Transaction has Expense, Income, and Quick Add tabs. In **Quick Add**, type a
sentence such as `50k lunch cash yesterday`, then choose **Fill transaction details**.
The editor switches to the matching Expense or Income tab to review or complete
the fields before tapping **Save**. Quick Add text is retained when switching tabs. Swipe left or right across the
form to move between Income, Expense, and Quick Add; vertical drags still scroll
the form. Swipes stop at the first and last tab. A directional 3D page-turn animation
accompanies each swipe, with a short crossfade when Reduce Motion is enabled.
Filling the form does not write transactions or pending captures. Expense entries retain the selected trip and
funding jar; income entries clear that expense-only routing.

**Record Transaction** is the only Siri app shortcut. The former Quick Capture
shortcut has been removed; existing quick-capture URLs open Add Transaction.

### Gold unit labels

Gold forms, quotes, and holding summaries use **mace / tael** in English and
**chỉ / lượng** in Vietnamese, following the selected app language. This changes
labels only: stored weights and the ten-to-one conversion are unchanged.

### Date display

In Settings → Date format, choose `dd/MM/yyyy` (default),
`MM/dd/yyyy`, or `yyyy-MM-dd`. The choice is saved on this device and applies
immediately, independently of the interface language. Each option shows a sample
date, and the selected option has a checkmark. Date-time labels retain
the localized time, and month/year headings retain their existing labels.
Backup files, bank imports, and API date encodings keep their existing formats.

### Reordering quick expenses

In **Defaults → Quick expenses**, touch and hold a preset, then drag it onto another
preset to move it to that position. Tapping still opens the editor. The order saves
immediately and the widget uses the same order. Preset names, amounts, categories,
and shortcut identities stay with their items. Hidden presets keep their order;
increase **Presets shown** to include them. VoiceOver offers **Move earlier** and
**Move later** actions. Dropping outside the grid leaves the order unchanged.

### Peer-to-peer device sync

Open **Settings → Device Sync** on both devices. On Mac, choose **Pair an iPhone**;
on iPhone, scan that QR code. Keep the pairing code private: it authorizes access
to this pair's financial data. Camera access is only needed for scanning; a manual
code entry is available. Subsequent sessions use **Connect**, then **Sync** from
either device. Both apps must be open and unlocked on the same Wi-Fi. Local Network
permission is required; guest-network isolation and firewalls can prevent discovery.

Every sync shows a preview. The initiating device chooses between conflicting
records and confirms **Apply to both devices**. The receiving device then reviews
the final changes and must apply or cancel. Initial sync unions existing data;
a starter category/account/jar missing on one device requires an explicit keep or
remove decision. Hand-entered transactions with different IDs remain separate,
even when their date and amount match. Recurring occurrences and imported records
use their existing domain identities. A deletion cannot strand a retained record
that needs the deleted item: retain the referenced item or change the choices.
Existing optional provenance, such as a deleted recurring rule, is preserved.

Financial records sync; pending captures and preferences stay local. Local draft,
default-account/category, import mapping, and Quick Expense references follow
merged IDs or become unselected if their target was deleted. Theme, language,
app lock, notification choices, and MCP authorization never come from the peer.

No background or remote-Internet sync is attempted. Leaving the app or locking it
interrupts the connection. Reconnect to finish an interrupted session. The status
is complete only after both stores have saved the reviewed result. An uncommitted
prepared store stays read-only until recovery; an already committed store can keep
new edits, which participate in the next sync rather than being overwritten on retry.
A prepared session with no preparation on its peer is safely abandoned on reconnect.

The most recent 20 completed sessions show per-device change counts. A recovery
backup is written locally before every commit; completed sessions offer export of
that backup. Recovery files are in the app's Application Support directory under
`MonMon/p2p-recovery/<dev|prod>/`. Files are retained locally until removed by the owner. They contain financial data and local preferences,
not pairing secrets. A recovery from an already-corrupt store preserves its duplicate
rows; ordinary backup import will reject conflicting duplicate IDs rather than
silently discard a version. Preserve that file for explicit reconciliation.

Unpairing keeps financial data. An unfinished session must finish first. Restoring
a backup invalidates pairing and the common baseline, so unpair the other device
and pair again to preview an initial merge. Missing/corrupt sync metadata or different
protocol versions never trigger a blind replacement of a store. Dev and Prod use
separate service identifiers, pairing namespaces, and recovery directories.

Implementation notes: SwiftData remains local; a versioned canonical snapshot
and common baseline drive three-way reconciliation. Messages are length-prefixed
and each snapshot is capped at 100 MiB. TLS-PSK uses TLS 1.2 with AES-GCM because
[Apple's Network framework does not support TLS 1.3 PSK](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework).
The 256-bit pairing secret lives in non-synchronizing, device-only Keychain storage.
Data and local apply receipts commit in one SwiftData save; reconnect retries use
receipts, not a repeated restore. This is resumable synchronization, not a distributed
atomic transaction: one store can temporarily be ahead of the other.

No financial changes are committed while the receiving device is still reviewing.
Transfers imported from complementary statement sides without a common provenance
key remain separate; equal amounts and dates alone do not prove identity.
