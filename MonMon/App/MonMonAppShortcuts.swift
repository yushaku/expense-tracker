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

        AppShortcut(
            intent: OpenQuickCaptureIntent(),
            phrases: ["Open quick capture in \(.applicationName)"],
            shortTitle: "Quick Capture",
            systemImageName: "square.and.pencil"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
