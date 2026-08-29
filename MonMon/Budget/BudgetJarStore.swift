import SwiftData

enum BudgetJarStoreError: Error, Equatable {
    case protectedJar
}

@MainActor
enum BudgetJarStore {
    static func delete(
        _ jar: BudgetJar,
        jars: [BudgetJar],
        categories: [TransactionCategory],
        in context: ModelContext
    ) throws {
        guard !jar.isProtected else {
            throw BudgetJarStoreError.protectedJar
        }

        let replacement = BudgetJarRouting.fallback(in: jars, excluding: jar.id)

        for category in categories where category.budgetJarID == jar.id {
            category.budgetJarID = replacement?.id
        }

        context.delete(jar)
        try context.save()
    }
}
