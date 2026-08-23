import Foundation

enum TransactionSummary {
    static func totalIncome(of transactions: [MoneyTransaction]) -> Decimal {
        transactions.reduce(Decimal.zero) { total, transaction in
            transaction.kind == .income ? total + transaction.amount : total
        }
    }

    static func totalExpense(of transactions: [MoneyTransaction]) -> Decimal {
        transactions.reduce(Decimal.zero) { total, transaction in
            transaction.kind == .expense ? total + transaction.amount : total
        }
    }

    static func net(of transactions: [MoneyTransaction]) -> Decimal {
        totalIncome(of: transactions) - totalExpense(of: transactions)
    }

    /// Money recorded into this account minus money recorded out of it, over all
    /// time. Balances are never month-scoped; only the list is.
    static func netFlow(for account: CashAccount, transactions: [MoneyTransaction]) -> Decimal {
        transactions.reduce(Decimal.zero) { total, transaction in
            transaction.accountID == account.id ? total + transaction.signedAmount : total
        }
    }

    static func count(for account: CashAccount, transactions: [MoneyTransaction]) -> Int {
        transactions.filter { $0.accountID == account.id }.count
    }

    static func count(
        for category: TransactionCategory,
        transactions: [MoneyTransaction]
    ) -> Int {
        transactions.filter { $0.categoryID == category.id }.count
    }

    static func inRange(
        _ range: TransactionRange,
        transactions: [MoneyTransaction]
    ) -> [MoneyTransaction] {
        transactions.filter { range.contains($0.occurredAt) }
    }
}
