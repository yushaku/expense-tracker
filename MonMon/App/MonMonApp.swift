import AppIntents
import Foundation
import SwiftData
import SwiftUI

#if os(macOS)
    @main
    @MainActor
    enum MonMonEntryPoint {
        static func main() async {
            if CommandLine.arguments.contains("--mcp-stdio") {
                await MCPServerAdapter.runStdio()
                return
            }
            MonMonApp.main()
        }
    }
#endif

#if !os(macOS)
    @main
#endif
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock: AppLock
    @State private var storeReset = StoreResetCoordinator()
    @State private var appRoute: AppRoute
    @State private var notificationCoordinator: NotificationCoordinator
    #if os(macOS)
        @State private var mcpAccessManager: MCPAccessManager
    #endif
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let appLock = AppLock()
        let appRoute = AppRoute()
        let notificationCoordinator = NotificationCoordinator()
        _appLock = State(initialValue: appLock)
        _appRoute = State(initialValue: appRoute)
        _notificationCoordinator = State(initialValue: notificationCoordinator)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(
                for: Schema(MonMonSchema.models),
                configurations: Self.modelConfiguration
            )
        } catch {
            fatalError("Model container failed: \(error)")
        }
        container = modelContainer
        modelContainer.mainContext.autosaveEnabled = false
        if !MonMonProcess.isRunningUnitTests {
            do { try LegacySyncCleanup.run(in: modelContainer.mainContext) } catch {
                // Leftover rows are inert; the next launch tries again.
                assertionFailure("Legacy sync cleanup failed: \(error)")
            }
        }
        var canInitializeStore = true
        do { try SeedState.migrateExistingStore(in: modelContainer.mainContext) } catch {
            canInitializeStore = false
        }

        let transactionCaptureDependency = TransactionCaptureIntentDependency(
            container: modelContainer
        )
        AppDependencyManager.shared.add(dependency: transactionCaptureDependency)
        AppDependencyManager.shared.add(
            dependency: QuickExpenseIntentDependency { slot in
                let preset = QuickExpensePresetStore().preset(for: slot)
                _ = try await transactionCaptureDependency.recordQuickExpense(preset)
            }
        )

        if canInitializeStore {
            AccountSeed.seedDefaultBankIfNeeded(in: modelContainer.mainContext)
            AccountSeed.ensureUnassignedExists(in: modelContainer.mainContext)
            CategorySeed.seedIfEmpty(in: modelContainer.mainContext)
            BudgetJarSeed.seedIfNeeded(in: modelContainer.mainContext)

            do {
                try StoreReconciler.reconcile(in: modelContainer.mainContext)
            } catch {
                // A store that opened is worth showing. A duplicate that survives
                // renders as two rows the owner can merge by hand, which is worse
                // than folding it and better than not launching.
                assertionFailure("Reconcile failed: \(error)")
            }

            do {
                // After reconciling, so a rule that arrived twice has been folded
                // into one before either copy is asked what it owes.
                try RecurringGenerator.generate(in: modelContainer.mainContext)
            } catch {
                // The same bargain: an entry the owner adds by hand is a smaller
                // loss than a launch that does not happen.
                assertionFailure("Recurring generation failed: \(error)")
            }

        }
        GoalWidgetSnapshot.refresh(in: modelContainer.mainContext)
        WidgetTodayExpenses.refresh(in: modelContainer.mainContext)
        #if os(macOS)
            do {
                let configuration = try MCPRuntimeConfiguration.current()
                _mcpAccessManager = State(
                    initialValue: try MCPAccessManager(
                        configuration: configuration,
                        sourceContext: modelContainer.mainContext
                    )
                )
            } catch {
                fatalError("MCP configuration failed")
            }
        #endif
    }

    private static var modelConfiguration: ModelConfiguration {
        if MonMonProcess.isRunningUnitTests {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        }

        return ModelConfiguration(cloudKitDatabase: .none)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("Backup", isPresented: $storeReset.isPresentingResetNotice) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Database reset complete. Find your backup in Settings → Backup.")
                }
                .environment(storeReset)
                .environment(appLock)
                .environment(appRoute)
                .environment(notificationCoordinator)
                .task {
                    storeReset.onReset = {
                        Task { await notificationCoordinator.reconcile(in: container.mainContext) }
                    }
                    await notificationCoordinator.reconcile(in: container.mainContext)
                }
                #if os(macOS)
                    .environment(mcpAccessManager)
                #endif
                // Coming back to the app is the next moment the owner could see
                // a duplicate a background writer (an App Intent, the share
                // extension) left behind, so the store is reconciled again here.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    GoalWidgetSnapshot.refresh(in: container.mainContext)
                    WidgetTodayExpenses.refresh(in: container.mainContext)
                    _ = try? StoreReconciler.reconcile(in: container.mainContext)
                    // Coming back is also the moment a rule can have fallen due
                    // since the app was opened — an app left running overnight
                    // would otherwise not record today until it was relaunched.
                    _ = try? RecurringGenerator.generate(in: container.mainContext)
                    Task {
                        await notificationCoordinator.reconcile(in: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}
