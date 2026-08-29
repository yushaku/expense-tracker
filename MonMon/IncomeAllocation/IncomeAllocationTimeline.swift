import Foundation

@MainActor
enum IncomeAllocationTimeline {
    enum Source: Equatable {
        case recurring
        case imported
        case oneOff
    }

    struct Event: Equatable, Identifiable {
        let id: UUID
        let amount: Decimal
        let occurredAt: Date
        let note: String
        let source: Source
        let snapshot: IncomeAllocationSnapshot
    }

    struct Preparation: Equatable {
        var events: [Event]
        var invalidCount: Int

        static let empty = Preparation(events: [], invalidCount: 0)

        var totalAmount: Decimal {
            events.reduce(Decimal.zero) { $0 + $1.amount }
        }
    }

    static func prepare(
        transactions: [MoneyTransaction],
        monthContaining month: Date
    ) -> Preparation {
        let range = TransactionRange.month(containing: month)
        var events: [Event] = []
        var invalidCount = 0

        for transaction in transactions
        where transaction.kind == .income && range.contains(transaction.occurredAt) {
            do {
                guard let snapshot = try IncomeAllocationLifecycle.snapshot(in: transaction) else {
                    invalidCount += 1
                    continue
                }
                events.append(
                    Event(
                        id: transaction.id,
                        amount: transaction.amount,
                        occurredAt: transaction.occurredAt,
                        note: transaction.note,
                        source: source(of: transaction),
                        snapshot: snapshot
                    )
                )
            } catch {
                invalidCount += 1
            }
        }

        events.sort {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return Preparation(events: events, invalidCount: invalidCount)
    }

    private static func source(of transaction: MoneyTransaction) -> Source {
        if transaction.sourceRuleID != nil {
            return .recurring
        }
        if transaction.sourceImportID != nil {
            return .imported
        }
        return .oneOff
    }
}
