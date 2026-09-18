import AppIntents
import SwiftUI

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
                    .settingsButtonLabelStyle()
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
}
