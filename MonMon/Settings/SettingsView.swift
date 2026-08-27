import AppIntents
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(CloudSync.self) private var cloudSync
    @Environment(\.modelContext) private var modelContext

    @Environment(\.locale) private var locale

    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system
    @AppStorage(AppLock.enabledKey) private var isLockEnabled = false
    @State private var instrumentScope: FundInstrumentListScope?

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        appearanceCard
                        voiceCaptureCard
                        instrumentsCard
                        securityCard
                        backupCard
                        aboutCard
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .compactRootNavigationTitle("Settings")
            .accessibilityIdentifier("settings")
            .tint(MonMonTheme.accent)
            .sheet(item: $instrumentScope) { scope in
                FundInstrumentListView(scope: scope)
            }
        }
    }

    private static let syncedTemplate = Date.FormatStyle().day().month(.abbreviated).year()
        .hour().minute()

    private var appearanceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Appearance", systemImage: "paintbrush.fill")

                Picker("Theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Label(option.displayName, systemImage: option.symbolName)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("theme-picker")

                Divider()
                    .overlay(MonMonTheme.border)

                // The card is headed Appearance, which the theme picker under it
                // reads as. The language picker needs saying.
                Text("Language")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)

                // Each language names itself, so the picker can be read whichever
                // one is currently on show.
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("language-picker")
            }
        }
    }

    private var securityCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Security", systemImage: "lock.fill")

                Toggle(isOn: lockBinding) {
                    Text("Require \(appLock.biometryName)")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .tint(MonMonTheme.accent)
                .accessibilityIdentifier("biometric-lock")

                Text(lockExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                if let failureMessage = appLock.failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.danger)
                        .accessibilityIdentifier("biometric-lock-error")
                }
            }
        }
    }

    private var voiceCaptureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Siri & Shortcuts", systemImage: "waveform.badge.mic")

                Label("Two shortcuts are ready", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.accent)

                Text("They are installed automatically with MonMon—nothing else to download.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Divider()
                    .overlay(MonMonTheme.border)

                shortcutRow(
                    title: "Record Transaction",
                    detail: "Say “Siri, record a transaction in MonMon”, then answer “cafe 50k”.",
                    systemImage: "square.and.pencil"
                )

                shortcutRow(
                    title: "Quick Capture",
                    detail: "Opens the focused entry form when voice is not convenient.",
                    systemImage: "square.and.pencil"
                )

                voiceShortcutInstructions
            }
        }
    }

    private func shortcutRow(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(MonMonTheme.accent)
        }
    }

    private var voiceShortcutInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create one-tap voice capture")
                .font(.subheadline.weight(.semibold))

            Text("Combine Dictate Text with MonMon so one tap starts listening.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            instructionRow(number: 1, text: "Open Shortcuts and tap +.")
            instructionRow(number: 2, text: "Add Dictate Text.")
            instructionRow(
                number: 3,
                text: "Add MonMon → Record Transaction, then set Transaction to Dictated Text."
            )
            instructionRow(
                number: 4,
                text: "Name it Voice Capture and tap it whenever you want to record."
            )

            #if os(iOS)
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .accessibilityIdentifier("open-monmon-shortcuts")
                    .padding(.top, 2)
            #endif
        }
        .padding(.top, 2)
    }

    private func instructionRow(number: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number.formatted())
                .font(.caption2.weight(.bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 22, height: 22)
                .background(MonMonTheme.accent, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private var instrumentsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Instruments", systemImage: "list.bullet.rectangle.fill")

                instrumentButton(
                    title: "Funds & ETFs",
                    subtitle: "Manage catalogue prices and Fmarket imports",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: MonMonTheme.funds,
                    scope: .funds
                )

                Divider()
                    .overlay(MonMonTheme.border)

                instrumentButton(
                    title: "Gold",
                    subtitle: "Manage products and shop buy/sell prices",
                    systemImage: "seal.fill",
                    tint: MonMonTheme.Hue.peach,
                    scope: .gold
                )
            }
        }
    }

    private func instrumentButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        scope: FundInstrumentListScope
    ) -> some View {
        Button {
            instrumentScope = scope
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens instrument management")
        .accessibilityIdentifier("settings-\(scope.rawValue)-instruments")
    }

    /// Turning the lock on runs an authentication first, so a sensor that does
    /// not work is found now rather than at the next launch. The stored flag is
    /// written by `AppLock`, never straight from the switch.
    private var lockBinding: Binding<Bool> {
        Binding(
            get: { isLockEnabled },
            set: { newValue in
                Task { await appLock.setEnabled(newValue) }
            }
        )
    }

    private var lockExplanation: LocalizedStringKey {
        """
        Asks for \(appLock.biometryName) when the app opens, and again after a minute away. \
        This hides the screen; it does not encrypt the file your records are stored in.
        """
    }

    private var backupCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Backup", systemImage: "icloud.fill")

                Toggle(isOn: syncBinding) {
                    Text("Sync to iCloud")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .tint(MonMonTheme.accent)
                .accessibilityIdentifier("icloud-sync")

                Text(
                    """
                    Keeps every record in your own private iCloud database, so your iPhone and\
                     Mac show the same books. Nobody else can read it, MonMon included.
                    """
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

                if cloudSync.needsRelaunch {
                    Label(
                        "Quit MonMon and open it again to apply this.",
                        systemImage: "arrow.clockwise.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("icloud-sync-relaunch")
                }

                if cloudSync.isEnabled {
                    syncControls
                }

                BackupRestoreView()
            }
        }
    }

    @ViewBuilder
    private var syncControls: some View {
        Divider()
            .overlay(MonMonTheme.border)

        HStack(spacing: 12) {
            Button {
                Task { await cloudSync.syncNow(context: modelContext) }
            } label: {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.prominentAction)
            .disabled(cloudSync.isSyncing || cloudSync.needsRelaunch)
            .accessibilityIdentifier("icloud-sync-now")

            if cloudSync.isSyncing {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 0)
        }

        Text(lastSyncedText)
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
            .accessibilityIdentifier("icloud-last-synced")

        if let message = cloudSync.message {
            Label(
                message.text,
                systemImage: message.isFailure
                    ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(message.isFailure ? MonMonTheme.danger : MonMonTheme.textSecondary)
            .accessibilityIdentifier("icloud-sync-message")
        }
    }

    /// Turning synchronisation on or off only rewrites the preference. The store
    /// this launch opened keeps mirroring, or not, until the app is relaunched.
    private var syncBinding: Binding<Bool> {
        Binding(
            get: { cloudSync.isEnabled },
            set: { cloudSync.setEnabled($0) }
        )
    }

    private var lastSyncedText: String {
        guard let lastSyncedAt = cloudSync.lastSyncedAt else {
            return "No sync recorded yet on this device."
        }

        let day = TransactionPeriod.format(Self.syncedTemplate, in: locale).format(lastSyncedAt)

        return AppText.string("Last synced \(day).", in: locale)
    }

    private var aboutCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("About", systemImage: "info.circle.fill")

                Text(storageExplanation)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var storageExplanation: LocalizedStringKey {
        cloudSync.isEnabled
            ? """
            MonMon keeps everything on this device and in your own iCloud account. No MonMon \
            account, no server of ours.
            """
            : "MonMon keeps everything on this device. No account, no network."
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }
}

#if DEBUG
    #Preview("Settings") {
        SettingsView()
            .environment(AppLock(isLocked: false))
            .environment(CloudSync())
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
