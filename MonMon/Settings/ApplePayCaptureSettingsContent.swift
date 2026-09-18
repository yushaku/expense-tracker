import SwiftData
import SwiftUI

enum ApplePayCaptureShortcut {
    static let installURL = URL(
        string: "https://www.icloud.com/shortcuts/2e5d68434e3a4cfba96d94b0a9dac317")
}

struct ApplePayCaptureSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            ApplePayCaptureSetup().appCard()
            ApplePayCapturePreferences().appCard()
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
            Text("Ready-made Apple Pay shortcut")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let url = ApplePayCaptureShortcut.installURL {
                Link(destination: url) {
                    Label("Install shortcut", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("apple-pay-install-shortcut")
                .accessibilityHint(
                    "Opens the shared shortcut on iCloud. Confirm installation in Shortcuts.")
            }
            Text(
                "After adding it, create a Wallet / Transaction automation, select your card and Run Immediately, then choose this shortcut."
            )
            Text(
                "The Wallet trigger starts the automation; the shortcut sends that transaction to MonMon."
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
        }
        .font(.subheadline)
    }
}
