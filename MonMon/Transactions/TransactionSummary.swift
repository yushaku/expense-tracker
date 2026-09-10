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

    /// Money in hand as it ran up over the days that recorded anything, oldest
    /// first. Each point is every day up to and including it, so the line only
    /// ever tells one story: where the period had got to by then.
    static func runningNet(_ transactions: [MoneyTransaction]) -> [TransactionNetPoint] {
        var running = Decimal.zero

        return byDay(transactions).reversed().map { group in
            running += group.net

            return TransactionNetPoint(day: group.day, net: running)
        }
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

/// Where the running total had got to by the end of one day.
struct TransactionNetPoint: Identifiable, Equatable {
    let day: Date
    let net: Decimal

    var id: Date { day }
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

/// Which direction a transaction query keeps. Screens decide which sections
/// consume that query, so a global filter can drive every total and chart.
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

/// Presentation-only union: transfers retain their own ledger records and never
/// become income or expenses just because they appear in the same history.
enum TransactionHistoryEntry: Identifiable {
    case transaction(MoneyTransaction)
    case transfer(AccountTransfer)

    var id: String {
        switch self {
        case .transaction(let value): "transaction-\(value.id.uuidString)"
        case .transfer(let value): "transfer-\(value.id.uuidString)"
        }
    }

    var occurredAt: Date {
        switch self {
        case .transaction(let value): value.occurredAt
        case .transfer(let value): value.occurredAt
        }
    }

    var createdAt: Date {
        switch self {
        case .transaction(let value): value.createdAt
        case .transfer(let value): value.createdAt
        }
    }

    var signedAmount: Decimal {
        switch self {
        case .transaction(let value): value.signedAmount
        case .transfer: 0
        }
    }
}

struct TransactionHistoryDay: Identifiable {
    let day: Date
    let entries: [TransactionHistoryEntry]
    var id: Date { day }
    var net: Decimal { entries.reduce(0) { $0 + $1.signedAmount } }
}

enum TransactionHistory {
    static func byDay(
        transactions: [MoneyTransaction], transfers: [AccountTransfer]
    ) -> [TransactionHistoryDay] {
        let entries =
            transactions.map(TransactionHistoryEntry.transaction)
            + transfers.map(TransactionHistoryEntry.transfer)
        let sorted = entries.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
        let groups = Dictionary(grouping: sorted) {
            TransactionPeriod.calendar.startOfDay(for: $0.occurredAt)
        }
        return groups.keys.sorted(by: >).map {
            TransactionHistoryDay(day: $0, entries: groups[$0] ?? [])
        }
    }
}
