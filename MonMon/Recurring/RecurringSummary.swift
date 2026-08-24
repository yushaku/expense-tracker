import Foundation

/// Pure reducers over recurring rules, shaped like `TransactionSummary` so a
/// screen counts a rule the way it already counts a transaction.
enum RecurringSummary {
    static func count(for account: CashAccount, rules: [RecurringRule]) -> Int {
        rules.filter { $0.accountID == account.id }.count
    }

    static func count(for category: TransactionCategory, rules: [RecurringRule]) -> Int {
        rules.filter { $0.categoryID == category.id }.count
    }

    static func active(_ rules: [RecurringRule]) -> [RecurringRule] {
        rules.filter { !$0.isPaused }
    }

    static func paused(_ rules: [RecurringRule]) -> [RecurringRule] {
        rules.filter(\.isPaused)
    }

    /// Soonest due first, so what happens next is at the top. A rule with
    /// nothing left to do — paused, or past its end date — sinks below the rest
    /// rather than disappearing, and ties fall back on the name so the order
    /// never reshuffles itself between redraws.
    static func sortedForDisplay(_ rules: [RecurringRule], asOf: Date) -> [RecurringRule] {
        rules.sorted { left, right in
            switch (left.nextOccurrence(after: asOf), right.nextOccurrence(after: asOf)) {
            case (let leftDate?, let rightDate?):
                leftDate == rightDate ? left.note < right.note : leftDate < rightDate
            case (nil, _?):
                false
            case (_?, nil):
                true
            case (nil, nil):
                left.note < right.note
            }
        }
    }

    /// What one rule costs or brings in over a month, for the total a list shows
    /// at its head. A rule that repeats more often than monthly is counted as
    /// many times as it falls due in the month containing `asOf`, so a weekly
    /// and a monthly rule can be added together honestly.
    static func monthlyAmount(of rule: RecurringRule, asOf: Date) -> Decimal {
        guard !rule.isPaused else {
            return .zero
        }

        let start = TransactionPeriod.startOfMonth(for: asOf)
        let end = TransactionPeriod.endOfMonth(for: asOf)
        let lastDay = RecurrenceSchedule.calendar.date(byAdding: .day, value: -1, to: end) ?? end

        let bound = rule.endDate.map { min($0, lastDay) } ?? lastDay
        let dates = RecurrenceSchedule.occurrences(
            frequency: rule.frequency,
            interval: rule.interval,
            anchor: rule.anchorDate,
            after: RecurrenceSchedule.calendar.date(byAdding: .day, value: -1, to: start),
            through: bound,
            limit: RecurringRuleDraft.maxBackfill
        )

        return rule.amount * Decimal(dates.count)
    }

    /// Net across every rule: what comes in this month less what goes out.
    static func monthlyNet(of rules: [RecurringRule], asOf: Date) -> Decimal {
        rules.reduce(Decimal.zero) { total, rule in
            let amount = monthlyAmount(of: rule, asOf: asOf)
            return rule.kind == .income ? total + amount : total - amount
        }
    }
}
