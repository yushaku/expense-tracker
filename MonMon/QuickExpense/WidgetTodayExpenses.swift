import Foundation

struct WidgetTodayExpenses: Codable, Equatable, Sendable {
    struct Expense: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let title: String
        let amount: Decimal
    }

    let startOfDay: Date
    let endOfDay: Date
    let total: Decimal
    let count: Int
    let expenses: [Expense]
}

struct WidgetTodayExpensesStore {
    static let storageKey = "widgetTodayExpenses"
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? QuickExpenseWidgetConfiguration.makeDefaults()
    }

    func save(_ snapshot: WidgetTodayExpenses) throws {
        let data = try JSONEncoder().encode(snapshot)
        if defaults.data(forKey: Self.storageKey) != data {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func load(at date: Date) -> WidgetTodayExpenses? {
        guard let data = defaults.data(forKey: Self.storageKey),
            let snapshot = try? JSONDecoder().decode(WidgetTodayExpenses.self, from: data)
        else { return nil }
        guard date >= snapshot.startOfDay, date < snapshot.endOfDay else {
            // Never carry yesterday's spending into today's total. The next app
            // save publishes a fresh snapshot; WidgetKit cannot read the ledger.
            return WidgetTodayExpenses(
                startOfDay: snapshot.startOfDay, endOfDay: snapshot.endOfDay,
                total: 0, count: 0, expenses: [])
        }
        return snapshot
    }
}

#if !WIDGET_EXTENSION
    import SwiftData
    import WidgetKit

    extension WidgetTodayExpenses {
        @MainActor
        static func make(in context: ModelContext, at date: Date) throws -> Self {
            let calendar = TransactionPeriod.calendar
            let start = calendar.startOfDay(for: date)
            let end =
                calendar.date(byAdding: .day, value: 1, to: start)
                ?? start.addingTimeInterval(86_400)
            let transactions = try context.fetch(
                FetchDescriptor<MoneyTransaction>(
                    predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
                    sortBy: [
                        SortDescriptor(\.occurredAt, order: .reverse),
                        SortDescriptor(\.createdAt, order: .reverse),
                    ]
                )
            ).filter { $0.kind == .expense }.sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
            let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
            let rows = transactions.prefix(5).map { transaction in
                let note = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                let category = categories.first { $0.id == transaction.categoryID }
                return Expense(
                    id: transaction.id,
                    title: note.isEmpty
                        ? (category?.name ?? String(localized: "Uncategorized")) : note,
                    amount: transaction.amount)
            }
            return Self(
                startOfDay: start, endOfDay: end,
                total: transactions.reduce(0) { $0 + $1.amount },
                count: transactions.count, expenses: rows)
        }

        @MainActor
        static func refresh(in context: ModelContext) {
            guard !MonMonProcess.isRunningUnitTests else { return }
            do {
                let snapshot = try make(in: context, at: .now)
                let store = WidgetTodayExpensesStore()
                guard store.load(at: .now) != snapshot else { return }
                try store.save(snapshot)
                WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
            } catch {
                // A widget refresh must never turn a successful ledger save into
                // a failed transaction. Retry on the next save or app activation.
            }
        }
    }
#endif
