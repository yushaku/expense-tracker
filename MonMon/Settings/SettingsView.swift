import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(CloudSync.self) private var cloudSync
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(AppLock.enabledKey) private var isLockEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        appearanceCard
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
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings")
            .tint(MonMonTheme.accent)
        }
    }

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

                Text("Catppuccin Latte in light, Frappé in dark. System follows the device.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
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

    private var lockExplanation: String {
        "Asks for \(appLock.biometryName) when the app opens, and again after a "
            + "minute away. This hides the screen; it does not encrypt the file "
            + "your records are stored in."
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
                    "Keeps every record in your own private iCloud database, so your "
                        + "iPhone and Mac show the same books. Nobody else can read it, "
                        + "MonMon included."
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

        return "Last synced \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))."
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

    private var storageExplanation: String {
        cloudSync.isEnabled
            ? "MonMon keeps everything on this device and in your own iCloud account. "
                + "No MonMon account, no server of ours."
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
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
