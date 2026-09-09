import AppIntents
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLock.self) private var appLock
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(\.modelContext) private var modelContext

    @Environment(\.locale) private var locale

    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system
    @AppStorage(AppLock.enabledKey) private var isLockEnabled = false
    @AppStorage(AppDateFormat.storageKey) private var dateFormat = AppDateFormat.dayMonthYear
    @State private var instrumentScope: FundInstrumentListScope?

    var body: some View {
        #if os(macOS)
            settingsContent
                .frame(minWidth: 500, minHeight: 640)
        #else
            settingsContent
        #endif
    }

    private var settingsContent: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        card { AvatarSettingsContent() }
                        appearanceCard
                        instrumentsCard
                        notificationCard
                        voiceCaptureCard
                        securityCard
                        backupCard
                        #if os(macOS)
                            MCPSettingsCard()
                        #endif
                        aboutCard
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .compactRootNavigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(MonMonTheme.textSecondary)
                        .accessibilityIdentifier("settings-done")
                }
            }
            .accessibilityIdentifier("settings")
            .tint(MonMonTheme.accent)
            .appSheet(item: $instrumentScope) { scope in
                FundInstrumentListView(scope: scope)
            }
            .onChange(of: language) { _, newLanguage in
                Task {
                    await notificationCoordinator.reconcile(
                        in: modelContext,
                        locale: newLanguage.locale
                    )
                }
            }
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

                Divider()
                    .overlay(MonMonTheme.border)

                HStack {
                    Text("Date format")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)
                    Spacer(minLength: 8)
                    Picker("Date format", selection: $dateFormat) {
                        ForEach(AppDateFormat.allCases) { option in
                            Text(option.format(Self.dateFormatExample))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityIdentifier("date-format-picker")
                }

            }
        }
    }

    private static let dateFormatExample =
        TransactionPeriod.calendar.date(
            from: DateComponents(year: 2026, month: 12, day: 24)
        ) ?? .distantPast

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

    private var notificationCard: some View {
        card {
            NotificationSettingsCard()
        }
    }

    private var voiceCaptureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Siri & Shortcuts", systemImage: "waveform.badge.mic")

                Label("Record Transaction is ready", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.accent)

                Text("This shortcut is installed automatically with MonMon.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Divider()
                    .overlay(MonMonTheme.border)

                shortcutRow(
                    title: "Record Transaction",
                    detail: "Say “Siri, record a transaction in MonMon”, then answer “cafe 50k”.",
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
                    subtitle: "Manage catalogue prices and Fmarket or VNDIRECT imports",
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

                Divider()
                    .overlay(MonMonTheme.border)

                instrumentButton(
                    title: "Crypto",
                    subtitle: "Manage coins and CoinGecko imports",
                    systemImage: "bitcoinsign.circle.fill",
                    tint: MonMonTheme.crypto,
                    scope: .crypto
                )
            }
        }
    }

    private func instrumentButton(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
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
                sectionHeader("Backup", systemImage: "externaldrive.fill")

                BackupRestoreView()
            }
        }
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
        "MonMon keeps everything on this device. No account, no network."
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
            .environment(NotificationCoordinator())
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
