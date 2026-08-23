import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: CashAccount.self, SavingsDeposit.self, FundHolding.self,
                TransactionCategory.self, MoneyTransaction.self
            )
        } catch {
            fatalError("Model container failed: \(error)")
        }

        CategorySeed.seedIfEmpty(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
