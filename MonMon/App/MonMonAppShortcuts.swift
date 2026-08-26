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
            systemImageName: "mic.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
