import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock = AppLock()

    init() {
        do {
            // Purely additive against every earlier schema, so this opens with
            // no migration. See `FundInstrumentBackfill` for why the fund split
            // is linked up afterwards rather than staged here.
            container = try ModelContainer(for: Schema(MonMonSchema.models))
        } catch {
            fatalError("Model container failed: \(error)")
        }

        CategorySeed.seedIfEmpty(in: container.mainContext)

        do {
            try FundInstrumentBackfill.runIfNeeded(in: container.mainContext)
        } catch {
            // A store that opened is worth showing. Holdings the backfill could
            // not link render as "instrument missing" rather than taking the app
            // down, and the next launch tries again.
            assertionFailure("Fund backfill failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appLock)
        }
        .modelContainer(container)
    }
}
