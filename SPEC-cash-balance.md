# Spec: cash-balance

**Status:** Approved (2026-08-23)  
**Depends on:** `app-bootstrap`

## Objective

Deliver the first useful MonMon feature: the owner can create cash or bank
accounts with an opening balance, see a total cash balance, and find the same
accounts after relaunching the app on that device.

This slice uses local storage only. iCloud synchronization, income and expense
transactions, debt, investments, live prices, and MCP remain separate modules in
`CAPABILITY-MAP.md`.

## Scope

### User flow

1. Launch MonMon and see an empty state when no account exists.
2. Choose **Add Account**.
3. Enter a name, choose **Cash** or **Bank**, and enter a nonnegative opening
   balance in VND.
4. Save and return to the account list.
5. See each account's opening balance and their combined total.
6. Relaunch on the same device and see the saved accounts.

### Included

- Add and list cash or bank accounts.
- One currency: VND.
- Local SwiftData persistence.
- Empty, populated, validation-error, and persistence-error states.
- Shared SwiftUI implementation for native iPhone and Mac apps.

### Excluded

- Editing, deleting, archiving, or reordering accounts.
- Transactions or calculated balances after the opening balance.
- Multiple currencies, exchange rates, or financial institution connections.
- iCloud, CloudKit, market data, AI, or MCP access.
- UI automation; the owner performs hands-on app testing.

## Domain and Data Contract

SwiftData owns the persisted model. `CashAccountKind` is a `String`-backed,
`Codable` enum so the stored value remains explicit and readable.

```swift
enum CashAccountKind: String, Codable, CaseIterable {
    case cash
    case bank
}

@Model
final class CashAccount {
    var id: UUID
    var name: String
    var kind: CashAccountKind
    var openingBalance: Decimal
    var currencyCode: String
    var createdAt: Date
}
```

Rules:

- `name` is trimmed and must contain at least one non-whitespace character.
- `openingBalance` must parse as a finite, nonnegative decimal value.
- Input accepts ungrouped digits or Vietnamese grouping separators; display uses
  a locale-aware VND currency format with no fractional digits.
- The first slice always writes `currencyCode = "VND"`.
- Duplicate account names are allowed; `id` is the stable identity.
- Until transactions exist, the displayed account balance equals
  `openingBalance`.
- Totals use `Decimal`; `Double` and `Float` are forbidden for money.
- `createdAt` is supplied by the caller so tests do not depend on wall-clock
  time.

The form is the external-input boundary:

```swift
enum AccountFormError: Error, Equatable {
    case emptyName
    case invalidOpeningBalance
    case negativeOpeningBalance
}

struct AccountDraft: Equatable {
    var name = ""
    var kind: CashAccountKind = .cash
    var openingBalanceText = ""
}
```

Validation returns a valid account value or a typed error. A persistence error
keeps the form contents visible and shows a general save error; the app does not
dismiss the form as though the save succeeded.

## UI Contract

- `AccountListView` is the feature root and replaces the bootstrap Hello screen.
- The empty state explains that no cash accounts exist and provides one primary
  **Add Account** action.
- The populated state shows the total first, then rows ordered by `createdAt`
  ascending. Each row shows name, kind, and formatted balance.
- Add Account appears as a sheet with Name, Type, and Opening Balance fields,
  plus Cancel and Save actions.
- Validation errors appear inline beside the affected field. Save remains
  available so submitting invalid input reveals the exact error.
- Controls expose stable accessibility identifiers:
  `account-list`, `add-account`, `account-name`, `account-kind`,
  `opening-balance`, and `save-account`.
- Layout must remain usable with iPhone Dynamic Type and a resizable Mac window.

No platform-specific screen is introduced unless shared SwiftUI cannot express
the required behavior.

## Persistence Contract

- `MonMonApp` installs one `ModelContainer` containing `CashAccount`.
- `AccountListView` uses SwiftData `@Query` for live list updates.
- Add Account obtains `ModelContext` from the SwiftUI environment, inserts only
  after validation, and explicitly calls `save()` before dismissing. This makes
  save failure visible even though the main context supports autosave.
- Production uses the default local on-disk store.
- Automated persistence tests use `ModelConfiguration(isStoredInMemoryOnly:
  true)` and never touch the owner's app database.
- No CloudKit configuration or entitlement is added in this slice.

## Tech Stack

- Xcode 26.6 (17F113), Swift 6.3.3, and Swift language mode 6.
- One multiplatform Xcode target producing native iOS and macOS apps.
- SwiftUI and SwiftData only; no third-party dependencies.
- Swift Testing for unit and persistence tests.
- Minimum deployment versions: iOS 18 and macOS 15.
- Bundle identifier remains `com.sonlv.monmon`; changing it requires approval.

Official platform references:

- <https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches>
- <https://developer.apple.com/documentation/swiftdata/adding-and-editing-persistent-data-in-your-app>
- <https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(isstoredinmemoryonly:)>
- <https://developer.apple.com/documentation/foundation/decimal>

## Project Structure

```text
MonMon/
  App/
    MonMonApp.swift
    ContentView.swift
  Accounts/
    AccountDraft.swift
    AccountListView.swift
    AddAccountView.swift
    CashAccount.swift
    CashAccountKind.swift
    VNDCurrency.swift
MonMonTests/
  Accounts/
    AccountDraftTests.swift
    CashAccountPersistenceTests.swift
    CashBalanceSummaryTests.swift
```

Feature code stays together. Shared utilities are extracted only after another
feature actually needs them.

## Testing Strategy

Automated checks owned by the implementation:

- Start each validation, total-calculation, and persistence behavior with a
  failing Swift Testing test.
- Test name trimming and empty-name rejection.
- Test valid zero and positive balances plus nonnumeric and negative input.
- Test VND parsing without relying on the machine's current locale.
- Test total calculation for zero, one, and multiple accounts.
- Test insert, save, and fetch using an in-memory `ModelContainer`.
- Run unit/persistence tests on macOS, compile Debug and Release for macOS and
  the iOS Simulator SDK, and run strict formatting checks.

Hands-on checks owned by the owner:

- Empty state and Add Account presentation.
- Valid and invalid form submissions.
- Relaunch persistence on an actual chosen device.
- iPhone keyboard and Dynamic Type behavior.
- Mac window resizing and native interaction feel.

No automated test may depend on network access, iCloud, current locale,
wall-clock time, or the owner's real app database.

## Verification Commands

Run from the repository root:

```sh
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Debug \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon -configuration Release \
  -sdk iphonesimulator -derivedDataPath /tmp/MonMonDerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO build
rtk xcodebuild -project MonMon.xcodeproj -scheme MonMon \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/MonMonDerivedData CODE_SIGNING_ALLOWED=NO test
rtk swift format lint --strict --recursive MonMon MonMonTests
```

## Boundaries

### Always do

- Keep both platform builds healthy after every implementation increment.
- Validate input before inserting a SwiftData model.
- Preserve exact `Decimal` values and consistently format VND.
- Show clear empty, validation-error, and save-error states.
- Keep the feature small enough for the owner to evaluate before the next one.

### Ask first

- Change minimum OS versions or bundle identifier.
- Add a third-party dependency.
- Add editing, deletion, multiple currencies, or account-number fields.
- Enable iCloud or create a CloudKit schema.

### Never do

- Store bank credentials, account numbers, API keys, or secrets.
- Request financial institution access.
- Use `Double` or `Float` for balances.
- Add debt, investment, market-price, AI, or MCP behavior to this slice.
- Commit signing credentials or machine-specific Xcode user data.

## Success Criteria

- With no records, the app shows an understandable empty state and Add Account
  action.
- A valid cash or bank account with a nonnegative VND opening balance saves.
- Invalid input does not save and produces a clear inline error.
- A save failure is visible and does not discard entered form data.
- Saved accounts survive relaunch on the same device.
- The list displays every account balance and the exact combined total.
- Automated unit/persistence tests, strict formatting, and both platform builds
  pass without warnings introduced by this feature.
- The owner completes the hands-on checks and decides whether the feature is
  useful before `income-expense` begins.

## Open Questions

None. Any new requirement moves back through spec approval before implementation.
