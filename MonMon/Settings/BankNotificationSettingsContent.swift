import SwiftData
import SwiftUI

enum BankNotificationShortcut {
    static let installURL = URL(
        string: "https://www.icloud.com/shortcuts/31c50fdb6a794b2a999a97dff6f7a1e8")
}

struct BankNotificationSettingsContent: View {
    @Query(sort: \CashAccount.name) private var accounts: [CashAccount]
    @AppStorage(BankNotificationPreferences.accountKey) private var accountID = ""
    @AppStorage(BankNotificationPreferences.automaticSaveKey) private var automaticSave = false

    private var selectedAccountExists: Bool {
        accounts.contains { $0.id.uuidString == accountID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            BankNotificationShortcutInstall().appCard()

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
                .accessibilityIdentifier("bank-notification-account")
                Text("To use this default account, clear Account in the shortcut’s MonMon action.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                Toggle("Automatically save recognized transactions", isOn: $automaticSave)
                    .accessibilityIdentifier("bank-notification-auto-save")
                Text(
                    "Review your first capture in Transactions before enabling auto-save. Unknown formats and transfers still need review."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
            .appCard()
        }
    }
}

private struct BankNotificationShortcutInstall: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ready-made bank shortcut")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let url = BankNotificationShortcut.installURL {
                Link(destination: url) {
                    Label("Install shortcut", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("bank-notification-install-shortcut")
                .accessibilityHint(
                    "Opens the shared shortcut on iCloud. Confirm installation in Shortcuts.")
            }

            Text(
                "After adding it, open the shortcut: change TPBank to your bank app in Automation, select your own Account in the MonMon action, then enable the automation."
            )
            .font(.subheadline)
            Text("Set up on an iPhone with iOS 27 and MonMon installed.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            #if DEBUG
                Label(
                    "This shortcut saves to MonMon, not MonMon Dev. Choose the account and auto-save settings in MonMon.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityIdentifier("bank-notification-production-shortcut-notice")
            #endif
        }
    }
}
