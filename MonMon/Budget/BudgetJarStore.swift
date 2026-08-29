import SwiftData

enum BudgetJarStoreError: Error, Equatable {
    case jarFundsGoals
    case protectedJar
}

@MainActor
enum BudgetJarStore {
    static func delete(
        _ jar: BudgetJar,
        jars: [BudgetJar],
        categories: [TransactionCategory],
        goals: [FinancialGoal],
        in context: ModelContext
    ) throws {
        guard !jar.isProtected else {
            throw BudgetJarStoreError.protectedJar
        }
        guard !goals.contains(where: { $0.fundingJarID == jar.id }) else {
            throw BudgetJarStoreError.jarFundsGoals
        }

        let replacement = BudgetJarRouting.fallback(in: jars, excluding: jar.id)

        for category in categories where category.budgetJarID == jar.id {
            category.budgetJarID = replacement?.id
        }

        context.delete(jar)
        try context.save()
    }
}
