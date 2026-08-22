import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CashAccount.self)
    }
}
