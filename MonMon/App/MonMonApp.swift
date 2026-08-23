import SwiftData
import SwiftUI

@main
struct MonMonApp: App {
    private let container: ModelContainer
    @State private var appLock = AppLock()

    init() {
        do {
            container = try ModelContainer(
                for: CashAccount.self, SavingsDeposit.self, FundHolding.self,
                TransactionCategory.self, MoneyTransaction.self, AccountTransfer.self,
                Debt.self, DebtPayment.self
            )
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
