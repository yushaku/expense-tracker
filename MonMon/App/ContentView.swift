import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLock.self) private var appLock
    @Environment(AppRoute.self) private var appRoute

    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.system
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system

    var body: some View {
        RootTabView()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            // Reading the stored theme here as well as through
            // `MonMonTheme.colorScheme` is what makes a change repaint the whole
            // tree the moment it is picked.
            .preferredColorScheme(theme.colorScheme)
            // Every localized string and date format resolves against this,
            // so picking a language repaints the whole tree at once.
            .environment(\.locale, language.locale)
            .overlay {
                if appLock.isLocked {
                    LockScreenView(
                        biometryName: appLock.biometryName,
                        failureMessage: appLock.failureMessage,
                        isUnavailable: appLock.isUnavailable,
                        onUnlock: { Task { await appLock.authenticate() } },
                        onTurnOffLock: { Task { await appLock.setEnabled(false) } }
                    )
                    .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    appLock.noteEnteredForeground()
                case .inactive, .background:
                    appLock.noteLeftForeground()
                @unknown default:
                    break
                }
            }
            .onOpenURL { url in
                appRoute.receive(url, isLocked: appLock.isLocked)
            }
            .onChange(of: appLock.isLocked) { _, isLocked in
                appRoute.releaseQueuedQuickCapture(isLocked: isLocked)
            }
            .task {
                if appLock.isLocked {
                    await appLock.authenticate()
                }
            }
    }
}

#if DEBUG
    #Preview("App · accounts") {
        ContentView()
            .modelContainer(PreviewData.populated)
            .environment(AppLock(isLocked: false))
            .environment(AppRoute())
            .environment(NotificationCoordinator())
    }

    #Preview("App · empty") {
        ContentView()
            .modelContainer(PreviewData.empty)
            .environment(AppLock(isLocked: false))
            .environment(AppRoute())
            .environment(NotificationCoordinator())
    }
#endif
