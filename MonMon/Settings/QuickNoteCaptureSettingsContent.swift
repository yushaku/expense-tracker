import SwiftUI

enum QuickNoteCaptureShortcut {
    static let installURL = URL(
        string: "https://www.icloud.com/shortcuts/4da1dc6737a24e649447aa2e1e029e35")
}

struct QuickNoteCaptureSettingsContent: View {
    var body: some View {
        voiceCaptureCard.appCard()
    }

    private var voiceCaptureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Siri & Shortcuts", systemImage: "waveform.badge.mic")
                .font(.headline)
                .foregroundStyle(MonMonTheme.textPrimary)

            Label("Record Transaction is ready", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)

            Divider()
                .overlay(MonMonTheme.border)

            shortcutRow(
                title: "Record Transaction",
                detail: "Say “Siri, record a transaction in MonMon”, then answer “cafe 50k”.",
                systemImage: "square.and.pencil"
            )

            voiceShortcutInstall
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

    private var voiceShortcutInstall: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready-made voice capture shortcut")
                .font(.subheadline.weight(.semibold))

            if let url = QuickNoteCaptureShortcut.installURL {
                Link(destination: url) {
                    Label("Install shortcut", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("voice-capture-install-shortcut")
                .accessibilityHint(
                    "Opens the shared shortcut on iCloud. Confirm installation in Shortcuts.")
            }

            Text(
                "Install the ready-made shortcut, then tap it to dictate a transaction to MonMon."
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
        }
        .padding(.top, 2)
    }
}
