import Foundation
import SwiftUI

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

    static func matching(
        _ filter: TransactionListFilter,
        transactions: [MoneyTransaction]
    ) -> [MoneyTransaction] {
        guard let kind = filter.kind else {
            return transactions
        }

        return transactions.filter { $0.kind == kind }
    }

    /// Splits transactions into calendar days, newest day first. The order
    /// inside a day is the order handed in, so a list already sorted by
    /// `occurredAt` keeps that sorting instead of being shuffled by a second
    /// sort over dates that are usually identical.
    static func byDay(_ transactions: [MoneyTransaction]) -> [TransactionDayGroup] {
        let calendar = TransactionPeriod.calendar
        let days = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.occurredAt)
        }

        return days.keys.sorted(by: >).map { day in
            TransactionDayGroup(day: day, transactions: days[day] ?? [])
        }
    }
}

/// One calendar day of transactions, used by the spending list to put a date
/// over a run of cards instead of on every one of them.
struct TransactionDayGroup: Identifiable {
    let day: Date
    let transactions: [MoneyTransaction]

    var id: Date { day }

    var net: Decimal {
        TransactionSummary.net(of: transactions)
    }
}

/// Which direction the spending list is showing. The totals above it always
/// count both, so this narrows the list alone.
enum TransactionListFilter: String, CaseIterable, Identifiable {
    case all
    case income
    case expense

    var id: String { rawValue }

    var kind: TransactionKind? {
        switch self {
        case .all:
            nil
        case .income:
            .income
        case .expense:
            .expense
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .all:
            "All"
        case .income, .expense:
            kind?.displayName ?? ""
        }
    }
}
