import AppIntents
import SwiftData
import SwiftUI

struct ApplePayCaptureSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            ApplePayCapturePreferences().appCard()
            ApplePayCaptureSetup().appCard()
        }
    }
}

private struct ApplePayCapturePreferences: View {
    @Query(filter: #Predicate<CashAccount> { $0.currencyCode == "VND" }, sort: \CashAccount.name)
    private var accounts: [CashAccount]
    @AppStorage(ApplePayPreferences.accountKey) private var accountID = ""
    @AppStorage(ApplePayPreferences.automaticSaveKey) private var automaticSave = false

    private var selectedAccountExists: Bool {
        accounts.contains { $0.id.uuidString == accountID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Destination account").font(.headline)
            Picker("Account", selection: $accountID) {
                Text("Choose an account").tag("")
                if !accountID.isEmpty && !selectedAccountExists {
                    Text("Account unavailable").tag(accountID)
                }
                ForEach(accounts) { account in
                    Text(account.name).tag(account.id.uuidString)
                }
            }
            .accessibilityIdentifier("apple-pay-account")
            Text(
                "Choose Account in each card’s Shortcut action, or leave it empty to use this account."
            )
            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
            Toggle("Automatically save Apple Pay expenses", isOn: $automaticSave)
                .accessibilityIdentifier("apple-pay-auto-save")
            Text(
                "Off by default: captures wait in Needs review. Auto-save requires a valid VND amount, merchant, account and default expense category. Other currencies need a VND amount entered during review."
            )
            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
            Text(
                "Use only one automatic capture source per card. Apple Pay and bank notifications can describe the same payment and create duplicates."
            )
            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
        }
    }
}

private struct ApplePayCaptureSetup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect Apple Pay").font(.headline)
            Text(
                "1. On iPhone, create a Shortcuts automation with the Wallet / Transaction trigger. Select your card and Run Immediately if offered."
            )
            Text(
                "2. Add MonMon’s Record Apple Pay Transaction action. Set Amount to Shortcut Input → Amount and Merchant to Shortcut Input → Merchant. Keep the currency with Amount; do not convert it to Number or Text."
            )
            Text(
                "3. Set Transaction date to the event’s date if available, otherwise capture Current Date once. Choose the matching MonMon account. Card label is optional. Check your first payment in Needs review."
            )
            Text(
                "When retrying, reuse all original fields and the same date. A new date is a new event. Wallet may omit data or fail to trigger; a card tap does not confirm final settlement. This does not import Wallet history."
            )
            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
            #if os(iOS)
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .accessibilityIdentifier("apple-pay-open-shortcuts")
            #endif
        }
        .font(.subheadline)
    }
}
