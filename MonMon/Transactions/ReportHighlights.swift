import Foundation

struct ReportComparisonPeriods: Equatable {
    let current: TransactionRange
    let previous: TransactionRange

    init?(range: TransactionRange, asOf: Date) {
        let calendar = TransactionPeriod.calendar
        guard range.start <= asOf, range.end > range.start else { return nil }
        let previous: TransactionRange
        if range.scope == .custom {
            let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
            guard days > 0, let start = calendar.date(byAdding: .day, value: -days, to: range.start)
            else { return nil }
            previous = TransactionRange(scope: .custom, start: start, end: range.start)
        } else {
            previous = range.stepped(by: -1)
        }
        var currentEnd = range.end
        var previousEnd = previous.end
        if range.contains(asOf) {
            // Compare recorded calendar days, including today. If the previous
            // month is shorter, trim both windows to the same number of days.
            let todayEnd = TransactionRange.day(containing: asOf).end
            let elapsed = calendar.dateComponents([.day], from: range.start, to: todayEnd).day ?? 0
            let available =
                calendar.dateComponents([.day], from: previous.start, to: previous.end).day ?? 0
            let days = min(elapsed, available)
            guard days > 0,
                let end = calendar.date(byAdding: .day, value: days, to: range.start),
                let priorEnd = calendar.date(byAdding: .day, value: days, to: previous.start)
            else { return nil }
            currentEnd = min(end, range.end)
            previousEnd = priorEnd
        }
        current = TransactionRange(scope: .custom, start: range.start, end: currentEnd)
        self.previous = TransactionRange(scope: .custom, start: previous.start, end: previousEnd)
    }
}

struct ReportCategoryChange: Identifiable {
    let categoryID: UUID?
    let name: String?
    let currentTransactions: [MoneyTransaction]
    let previousTransactions: [MoneyTransaction]

    var id: String { categoryID?.uuidString ?? "uncategorized" }
    var current: Decimal { currentTransactions.reduce(0) { $0 + $1.amount } }
    var previous: Decimal { previousTransactions.reduce(0) { $0 + $1.amount } }
    var delta: Decimal { current - previous }
}

struct ReportHighlights {
    let periods: ReportComparisonPeriods
    let kind: TransactionKind
    let current: Decimal
    let previous: Decimal
    let changes: [ReportCategoryChange]
    let hasTransactions: Bool

    var delta: Decimal { current - previous }
    var percentageChange: Double? {
        guard previous > 0 else { return nil }
        return NSDecimalNumber(decimal: abs(delta) / previous).doubleValue
    }

    init?(
        query: TransactionQuery, transactions: [MoneyTransaction],
        categoryNames: [UUID: String], accountNames: [UUID: String], asOf: Date
    ) {
        guard let periods = ReportComparisonPeriods(range: query.range, asOf: asOf) else {
            return nil
        }
        self.periods = periods
        kind = query.filter.kind ?? .expense
        var currentQuery = query
        currentQuery.range = periods.current
        currentQuery.filter = kind == .income ? .income : .expense
        var previousQuery = currentQuery
        previousQuery.range = periods.previous
        let currentRows = TransactionSearch.results(
            of: currentQuery, transactions: transactions,
            categoryNames: categoryNames, accountNames: accountNames)
        let previousRows = TransactionSearch.results(
            of: previousQuery, transactions: transactions,
            categoryNames: categoryNames, accountNames: accountNames)
        current = currentRows.reduce(0) { $0 + $1.amount }
        previous = previousRows.reduce(0) { $0 + $1.amount }
        hasTransactions = !currentRows.isEmpty || !previousRows.isEmpty
        func categoryID(_ transaction: MoneyTransaction) -> UUID? {
            guard let id = transaction.categoryID, categoryNames[id] != nil else { return nil }
            return id
        }
        let currentGroups = Dictionary(grouping: currentRows, by: categoryID)
        let previousGroups = Dictionary(grouping: previousRows, by: categoryID)
        changes = Array(
            Set(currentGroups.keys).union(previousGroups.keys).map { id in
                ReportCategoryChange(
                    categoryID: id, name: id.flatMap { categoryNames[$0] },
                    currentTransactions: currentGroups[id] ?? [],
                    previousTransactions: previousGroups[id] ?? [])
            }.filter { $0.delta != 0 }.sorted {
                if abs($0.delta) != abs($1.delta) { return abs($0.delta) > abs($1.delta) }
                return $0.id < $1.id
            }.prefix(2))
    }
}
