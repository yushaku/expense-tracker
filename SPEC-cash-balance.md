# Spec: cash-balance

**Depends on:** `app-bootstrap`

## Objective

Deliver the smallest useful MonMon app that the owner can run on iPhone and Mac.
The owner can create cash or bank accounts with an opening balance, see those
accounts after relaunching the app, and see a total cash balance.

This slice deliberately uses local storage only. iCloud synchronization, income
and expense transactions, debt, investments, live prices, and MCP are separate
approved modules in `CAPABILITY-MAP.md`.

### User flow

1. Launch MonMon and see an empty state when no account exists.
2. Choose Add Account.
3. Enter a name, select Cash or Bank, and enter a nonnegative opening balance in
   VND.
4. Save and return to the account list.
5. See each account's balance and the combined cash total.
6. Relaunch on the same device and see the saved accounts.

### Domain contract

```swift
struct CashAccount: Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    let kind: CashAccountKind
    var openingBalance: Decimal
    let currencyCode: String
    let createdAt: Date
}
```

The form is the external-input boundary. It trims the account name, rejects an
empty name, rejects negative or nonnumeric balances, and converts valid text to
`Decimal` before saving. The initial slice supports VND only so totals never mix
currencies without exchange rates.

## Tech Stack

- Xcode 26.6 (build 17F113) and Swift 6.3.3, detected locally.
- One Xcode multiplatform app target producing native iOS and macOS apps.
- SwiftUI for shared UI and platform-adaptive presentation.
- SwiftData for local persistence.
- Swift Testing for unit and model tests; XCTest/XCUITest only if a UI behavior
  cannot be verified reliably below the UI layer.
- Minimum deployment versions: iOS 18 and macOS 15, as previously approved.
- Provisional bundle identifier: `com.sonlv.monmon`; it can be changed before the
  CloudKit container is created.

Official platform references:

- <https://developer.apple.com/documentation/Xcode/configuring-a-multiplatform-app-target>
- <https://developer.apple.com/documentation/SwiftUI>
- <https://developer.apple.com/documentation/SwiftData>

## Commands

The project scheme is `MonMon`. Run from the repository root:

```sh
xcodebuild -project MonMon.xcodeproj -scheme MonMon -destination 'platform=macOS' build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -destination 'platform=macOS' test
xcodebuild -project MonMon.xcodeproj -scheme MonMon -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project MonMon.xcodeproj -scheme MonMon -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

If the named simulator is unavailable, select an installed iPhone simulator from
`xcrun simctl list devices available` and record the actual destination in the
task evidence.

## Project Structure

```text
MonMon.xcodeproj/
MonMon/
  App/
    MonMonApp.swift
  Accounts/
    CashAccount.swift
    CashAccountKind.swift
    AccountListView.swift
    AddAccountView.swift
    AccountFormModel.swift
  Shared/
    CurrencyFormatting.swift
MonMonTests/
  Accounts/
    AccountFormModelTests.swift
    CashAccountTests.swift
MonMonUITests/
  CashBalanceFlowTests.swift
```

Feature code stays together so a small slice can be understood without traversing
several architecture layers. Shared code is extracted only after a second feature
actually needs it.

## Code Style

- Types use `UpperCamelCase`; properties, functions, and enum cases use
  `lowerCamelCase`.
- Use Swift's observation and SwiftData property wrappers only where their
  ownership is clear; do not create global mutable state.
- Pass dependencies through initializers or the SwiftUI environment.
- Use `Decimal` for balances and `FormatStyle` for locale-aware VND display.
- Keep views declarative; parsing and validation belong in the form model.
- Provide accessibility labels for controls whose visible text is insufficient.

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

## Testing Strategy

- Start each behavior with a failing Swift Testing test.
- Unit-test name trimming and every balance-validation outcome.
- Test SwiftData persistence with an in-memory `ModelContainer`; do not use the
  developer's real app database in automated tests.
- Test total-balance calculation with zero, one, and multiple accounts.
- Test the primary add-account flow on macOS and one iPhone simulator.
- Manually verify launch, empty state, add form, relaunch persistence, keyboard
  behavior on iPhone, and window resizing on Mac.
- No test may depend on network access, iCloud, current locale, or wall-clock time.

## Boundaries

### Always do

- Keep the project buildable for both iOS and macOS after every task.
- Validate user input before inserting a SwiftData model.
- Format balances as VND consistently and preserve exact `Decimal` values.
- Show a clear empty state and accessible form errors.
- Run focused tests and both platform builds before the module checkpoint.

### Ask first

- Change the minimum OS versions or bundle identifier.
- Add a third-party dependency.
- Add editing, deletion, multiple currencies, or account-number fields.
- Enable iCloud or create a production CloudKit schema.

### Never do

- Store bank credentials, account numbers, API keys, or secrets.
- Request financial institution access.
- Use `Double` or `Float` for balances.
- Add debt, investment, market-price, AI, or MCP behavior to this slice.
- Commit signing credentials or machine-specific Xcode user data.

## Success Criteria

- One shared Xcode target builds native apps for iOS and macOS.
- With no records, the app shows an understandable empty state and Add Account
  action.
- A valid cash or bank account with a nonnegative VND opening balance can be saved.
- Invalid input is not saved and produces a clear inline error.
- Saved accounts survive app relaunch on the same device.
- The account list displays each balance and the exact combined total.
- Automated unit/model tests pass; macOS and iPhone simulator builds pass.
- The owner can complete the full flow manually on at least one device and decide
  whether the feature is useful before `income-expense` begins.

## Open Questions

None. The provisional bundle identifier remains changeable until CloudKit work.
