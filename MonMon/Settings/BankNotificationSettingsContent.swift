import AppIntents
import SwiftData
import SwiftUI

struct BankNotificationSettingsContent: View {
    @Query(sort: \CashAccount.name) private var accounts: [CashAccount]
    @AppStorage(BankNotificationPreferences.accountKey) private var accountID = ""
    @AppStorage(BankNotificationPreferences.automaticSaveKey) private var automaticSave = false

    private var selectedAccountExists: Bool {
        accounts.contains { $0.id.uuidString == accountID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Connect a bank app", systemImage: "bell.badge")
                    .font(.headline)
                Text(
                    "Choose the app in Shortcuts on your iPhone. MonMon receives only the text your automation sends."
                )
                .font(.subheadline)
                Text(
                    "Notification automation requires iOS 27. Setup and locked-screen delivery must be checked on your iPhone."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
            .appCard()

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
                Text(
                    "For multiple banks, choose Account inside each MonMon action in Shortcuts. Leaving it empty uses this account."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
                Toggle("Automatically save recognized transactions", isOn: $automaticSave)
                    .accessibilityIdentifier("bank-notification-auto-save")
                Text(
                    "Start with review, then enable automatic saving after checking your bank’s messages. Unknown formats and transfers always need review. Income and expense use your default categories."
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
            .appCard()

            BankNotificationSetupSteps()
                .appCard()
        }
    }
}

private struct BankNotificationSetupSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up in Shortcuts").font(.headline)
            Text(
                "Set this up once for each bank app. First choose an account above and leave automatic saving off."
            )
            .font(.subheadline)

            BankNotificationGuideStep(number: 1, title: "Choose the bank app") {
                Text(
                    "Open Apple’s Shortcuts app → + to create a shortcut → Automation in the editor."
                )
                Text(
                    "Choose the trigger for receiving an app notification, then select your bank app. Choose Run Immediately if offered."
                )
                #if os(iOS)
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .accessibilityIdentifier("bank-notification-open-shortcuts")
                #endif
            }

            BankNotificationGuideStep(number: 2, title: "Add the MonMon action") {
                Text(
                    "In the action search box, search for MonMon. Select Record Bank Notification.")
                Text("If both MonMon and MonMon Dev appear, choose the app you are setting up now.")
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            BankNotificationGuideStep(number: 3, title: "Fill in these four fields") {
                Text("Tap each field in the MonMon action. Expand the action if Account is hidden.")
                BankNotificationGuideField(
                    title: "Notification text",
                    instruction:
                        "Select Variable → the notification supplied by the trigger → its message text.",
                    hint: "Select the notification’s text token; it updates for every new message."
                )
                BankNotificationGuideField(
                    title: "Source app",
                    instruction: "Type your bank app’s name, for example TPBank.",
                    hint: "This is a label you type once. The app itself was selected in step 1."
                )
                BankNotificationGuideField(
                    title: "Received at",
                    instruction: "Open the field’s variable menu and choose Current Date.",
                    hint: "Shortcuts will supply the date and time when the automation runs."
                )
                BankNotificationGuideField(
                    title: "Account",
                    instruction: "Select the MonMon account for this bank.",
                    hint: "You can also leave it empty to use the account selected above."
                )
            }

            BankNotificationGuideStep(number: 4, title: "Save and check the first notification") {
                Text(
                    "Save the shortcut. When your bank next sends a transaction notification, open MonMon → Transactions and review the pending entry."
                )
                Text(
                    "Check the amount, income or expense, and account. Enable automatic saving only after the first capture is recognized correctly."
                )
            }

            DisclosureGroup("If something is missing") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "No notification text to select? Check that step 1 uses the app-notification trigger. A blank shortcut has no incoming notification."
                    )
                    Text(
                        "Shortcuts runs but no text arrives? The bank may hide its message. Check one real notification with the phone unlocked, then one while locked."
                    )
                    Text(
                        "The Play button alone does not supply a bank notification. Check Transactions after an actual notification arrives."
                    )
                }
                .padding(.top, 8)
            }

            DisclosureGroup("Filters and duplicate notifications") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Once the connection works, add a text filter to the trigger using a phrase from your bank’s transaction notifications."
                    )
                    Text(
                        "If you retry a saved notification, reuse its original Received at value. A new Current Date is treated as a different event."
                    )
                }
                .padding(.top, 8)
            }
        }
        .font(.subheadline)
    }
}

private struct BankNotificationGuideStep<Content: View>: View {
    let number: Int
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number.formatted())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BankNotificationGuideField: View {
    let title: LocalizedStringKey
    let instruction: LocalizedStringKey
    let hint: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(instruction)
            Text(hint)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
