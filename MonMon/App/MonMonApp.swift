import AppIntents
import Foundation
import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock: AppLock
    @State private var syncCoordinator: SyncCoordinator
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
        let sync = SyncCoordinator(store: SyncSessionStore(container: modelContainer))
        sync.mayConnect = { !appLock.isLocked }
        _syncCoordinator = State(initialValue: sync)
        var canInitializeStore = !sync.writesLocked
        if canInitializeStore {
            do { try SeedState.migrateExistingStore(in: modelContainer.mainContext) } catch {
                canInitializeStore = false
            }
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
                .id(syncCoordinator.contentRevision)
                .disabled(syncCoordinator.writesLocked)
                .environment(syncCoordinator)
                .environment(appLock)
                .environment(appRoute)
                .environment(notificationCoordinator)
                .sheet(isPresented: $syncCoordinator.isPresented) {
                    SyncView()
                        .environment(syncCoordinator)
                        .environment(appLock)
                }
                .task {
                    syncCoordinator.onApplied = {
                        if let snapshot = try? syncCoordinator.store.snapshot() {
                            try? SyncLocalReferences.reconcile(snapshot)
                        }
                        Task { await notificationCoordinator.reconcile(in: container.mainContext) }
                        #if os(macOS)
                            mcpAccessManager.refreshSnapshotIfAllowed()
                        #endif
                    }
                    if !MonMonProcess.isRunningUnitTests,
                        let snapshot = try? syncCoordinator.store.snapshot(),
                        (try? syncCoordinator.store.state().baseline) != nil
                    {
                        try? SyncLocalReferences.reconcile(snapshot)
                    }
                    if syncCoordinator.writesLocked && !appLock.isLocked {
                        syncCoordinator.isPresented = true
                    }
                    await notificationCoordinator.reconcile(in: container.mainContext)
                }
                .onChange(of: appLock.isLocked) { _, locked in
                    if locked {
                        syncCoordinator.disconnect()
                    } else if syncCoordinator.writesLocked {
                        syncCoordinator.isPresented = true
                    }
                }
                #if os(macOS)
                    .environment(mcpAccessManager)
                #endif
                // Duplicates arrive when synchronisation lands, which is after
                // launch, so reconciling only in `init` would miss the case it
                // exists for. Coming back to the app is the next moment the
                // owner could see one.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else {
                        if phase == .background { syncCoordinator.disconnect() }
                        return
                    }
                    guard !syncCoordinator.writesLocked else {
                        if !appLock.isLocked { syncCoordinator.isPresented = true }
                        return
                    }
                    _ = try? StoreReconciler.reconcile(in: container.mainContext)
                    // Coming back is also the moment a rule can have fallen due
                    // since the app was opened — an app left running overnight
                    // would otherwise not record today until it was relaunched.
                    _ = try? RecurringGenerator.generate(in: container.mainContext)
                    Task {
                        await notificationCoordinator.reconcile(in: container.mainContext)
                    }
                    #if os(macOS)
                        mcpAccessManager.refreshSnapshotIfAllowed()
                    #endif
                }
        }
        .modelContainer(container)
    }
}
