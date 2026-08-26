import AppIntents
import Foundation
import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock = AppLock()
    @State private var cloudSync = CloudSync()
    @Environment(\.scenePhase) private var scenePhase

    init() {
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

        AppDependencyManager.shared.add(
            dependency: TransactionCaptureIntentDependency(container: modelContainer)
        )

        AccountSeed.seedDefaultBankIfNeeded(in: modelContainer.mainContext)
        AccountSeed.ensureUnassignedExists(in: modelContainer.mainContext)
        CategorySeed.seedIfEmpty(in: modelContainer.mainContext)

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

    private static var modelConfiguration: ModelConfiguration {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        }

        // The owner's switch is read here and nowhere else: SwiftData fixes a
        // store's mirroring when the container is built, so this launch is the
        // only moment the choice can take effect.
        guard CloudSync.isEnabled() else {
            return ModelConfiguration(cloudKitDatabase: .none)
        }

        return ModelConfiguration(cloudKitDatabase: .private(CloudSync.containerIdentifier))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
                .environment(cloudSync)
                .task { cloudSync.startObserving() }
                // Duplicates arrive when synchronisation lands, which is after
                // launch, so reconciling only in `init` would miss the case it
                // exists for. Coming back to the app is the next moment the
                // owner could see one.
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else {
                        return
                    }
                    _ = try? StoreReconciler.reconcile(in: container.mainContext)
                    // Coming back is also the moment a rule can have fallen due
                    // since the app was opened — an app left running overnight
                    // would otherwise not record today until it was relaunched.
                    _ = try? RecurringGenerator.generate(in: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
