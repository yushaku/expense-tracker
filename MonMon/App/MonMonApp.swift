import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock = AppLock()

    init() {
        do {
            container = try ModelContainer(for: Schema(MonMonSchema.models))
        } catch {
            fatalError("Model container failed: \(error)")
        }

        CategorySeed.seedIfEmpty(in: container.mainContext)
        AccountSeed.ensureUnassignedExists(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
        }
        .modelContainer(container)
    }
}
