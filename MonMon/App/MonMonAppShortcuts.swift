import AppIntents

struct MonMonAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureTransactionIntent(),
            phrases: [
                "Record a transaction in \(.applicationName)",
                "Add a transaction in \(.applicationName)",
            ],
            shortTitle: "Record Transaction",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: OpenQuickCaptureIntent(),
            phrases: ["Open quick capture in \(.applicationName)"],
            shortTitle: "Quick Capture",
            systemImageName: "square.and.pencil"
        )

        #if os(iOS)
            AppShortcut(
                intent: OpenVoiceCaptureIntent(),
                phrases: ["Start voice capture in \(.applicationName)"],
                shortTitle: "Voice Capture",
                systemImageName: "waveform"
            )
        #endif
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
