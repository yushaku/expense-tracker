import AppIntents
import SwiftData
import SwiftUI

struct BankNotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CashAccount.name) private var accounts: [CashAccount]
    @AppStorage(BankNotificationPreferences.accountKey) private var accountID = ""
    @AppStorage(BankNotificationPreferences.automaticSaveKey) private var automaticSave = false
    @AppStorage(BankNotificationPreferences.lastResultKey) private var lastResult = ""
    @AppStorage(BankNotificationPreferences.lastReceivedKey) private var lastReceived = 0.0
    @State private var sampleText = ""
    @State private var preview: ParsedTransactionCapture?
    @State private var previewError = false
    @State private var showsReview = false

    private var selectedAccountExists: Bool {
        accounts.contains { $0.id.uuidString == accountID }
    }

    var body: some View {
        ScrollView {
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Check a sample").font(.headline)
                    Text(
                        "Paste a notification to see whether MonMon can read it. This check never saves a transaction."
                    )
                    .font(.caption)
                    TextField("Notification text", text: $sampleText, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("bank-notification-sample")
                    Button("Check sample", systemImage: "text.magnifyingglass", action: checkSample)
                        .buttonStyle(.prominentAction)
                        .disabled(
                            !selectedAccountExists
                                || sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                        )
                    if previewError {
                        Text("Couldn’t check this sample. Check the account and notification text.")
                            .foregroundStyle(MonMonTheme.danger)
                    }
                    if let preview {
                        Text(
                            preview.isReady
                                ? "Recognized — eligible for automatic saving"
                                : "Needs review — will not be saved automatically"
                        )
                        .font(.subheadline.weight(.semibold))
                        if let amount = preview.amount {
                            HStack {
                                Text(preview.kind == .income ? "Income" : "Expense")
                                Text(VNDCurrency.format(amount))
                            }
                        }
                    }
                }
                .appCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent activity").font(.headline)
                    Text(statusText).font(.subheadline)
                    if lastReceived > 0 {
                        Text(
                            Date(timeIntervalSince1970: lastReceived),
                            format: .dateTime.day().month().hour().minute()
                        )
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                    }
                    Button("Needs review", systemImage: "tray") { showsReview = true }
                        .buttonStyle(.prominentAction)
                }
                .appCard()
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(MonMonTheme.canvas)
        .navigationTitle("Bank notifications")
        .foregroundStyle(MonMonTheme.textPrimary)
        .onChange(of: sampleText) {
            preview = nil
            previewError = false
        }
        .onChange(of: accountID) {
            preview = nil
            previewError = false
        }
        .appSheet(isPresented: $showsReview) { PendingTransactionCaptureListView() }
    }

    private var statusText: LocalizedStringKey {
        switch lastResult {
        case "saved": "Last notification saved as a transaction."
        case "review": "Last notification is waiting for review."
        case "duplicate": "Last notification was already received."
        case "failed": "Last attempt failed. Check the automation’s text and account."
        default: "No notification received yet. Run your automation to check the connection."
        }
    }

    private func checkSample() {
        do {
            preview = try TransactionCaptureService(container: modelContext.container)
                .prepareNotification(
                    BankNotificationEvent(text: sampleText, source: "Preview", receivedAt: .now),
                    accountID: UUID(uuidString: accountID), automaticSave: true
                )
            previewError = false
        } catch {
            preview = nil
            previewError = true
        }
    }
}

private struct BankNotificationSetupSteps: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set up in Shortcuts").font(.headline)
            Text(
                "1. Create a notification automation and choose your bank app. Add a filter for transaction messages."
            )
            Text(
                "2. Add MonMon → Record Bank Notification. Pass the notification’s text, including its title if needed, and enter the source app name."
            )
            Text(
                "3. Set Received at to the notification’s date if available. Otherwise, use Current Date once at the start. Reuse that value if you retry the same event."
            )
            Text(
                "4. Choose Account in the action, or leave it empty to use the account above. Set the automation to run immediately."
            )
            Text(
                "5. Keep automatic saving off for the first real notification. Check Needs review, including a test with your iPhone locked."
            )
            Text(
                "Create a separate automation for each bank app. If Shortcuts supplies no message text, this connection cannot create a transaction."
            )
            .foregroundStyle(MonMonTheme.textSecondary)
            #if os(iOS)
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .accessibilityIdentifier("bank-notification-open-shortcuts")
            #endif
        }
        .font(.subheadline)
    }
}
