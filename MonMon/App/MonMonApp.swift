import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock = AppLock()

    init() {
        do {
            // Every schema change so far has been additive, so this opens an
            // existing store with no migration. The one subtraction — the
            // pre-split columns the fund catalogue replaced — is a plain
            // attribute removal, which lightweight migration handles; it is the
            // *staged* kind that could not recognise a store this app had
            // already written.
            container = try ModelContainer(for: Schema(MonMonSchema.models))
        } catch {
            fatalError("Model container failed: \(error)")
        }

        CategorySeed.seedIfEmpty(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
        }
        .modelContainer(container)
    }
}
