import SwiftUI

struct SettingsView: View {
    @Environment(AppLock.self) private var appLock

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

    private var aboutCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("About", systemImage: "info.circle.fill")

                Text("MonMon keeps everything on this device. No account, no network.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
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
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
