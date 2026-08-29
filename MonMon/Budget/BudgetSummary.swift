import Foundation

struct BudgetJarSnapshot: Identifiable, Equatable {
    let jarID: UUID
    let name: String
    let allocationPercent: Decimal
    let role: BudgetJarRole
    let symbolName: String
    let colorName: String
    let planned: Decimal
    let received: Decimal
    let projected: Decimal
    let used: Decimal

    var id: UUID { jarID }

    var remaining: Decimal {
        projected - used
    }
}

struct BudgetSnapshot: Equatable {
    let month: Date
    let plannedIncome: Decimal
    let receivedIncome: Decimal
    let projectedIncome: Decimal
    let allocationPercent: Decimal
    let rows: [BudgetJarSnapshot]

    var unallocatedPercent: Decimal {
        max(0, 100 - allocationPercent)
    }

    var rowsByAllocation: [BudgetJarSnapshot] {
        rows.enumerated()
            .sorted { left, right in
                if left.element.allocationPercent == right.element.allocationPercent {
                    return left.offset < right.offset
                }
                return left.element.allocationPercent > right.element.allocationPercent
            }
            .map(\.element)
    }
}

struct BudgetJarActivitySnapshot {
    let transactions: [MoneyTransaction]
    let savingsDeposits: [SavingsDeposit]
    let fundHoldings: [FundHolding]

    var isEmpty: Bool {
        transactions.isEmpty && savingsDeposits.isEmpty && fundHoldings.isEmpty
    }
}

enum BudgetJarActivity {
    static func snapshot(
        for jar: BudgetJar,
        monthContaining month: Date,
        asOf: Date,
        jars: [BudgetJar],
        categories: [TransactionCategory],
        transactions: [MoneyTransaction],
        savingsDeposits: [SavingsDeposit],
        fundHoldings: [FundHolding]
    ) -> BudgetJarActivitySnapshot {
        let start = TransactionPeriod.startOfMonth(for: month)
        let end = TransactionPeriod.endOfMonth(for: month)
        let routing = BudgetTransactionRouting(jars: jars, categories: categories)
        let visibleTransactions = transactions.filter {
            $0.kind == .expense
                && BudgetSummary.contains($0.occurredAt, from: start, to: end, asOf: asOf)
                && routing.jarID(for: $0) == jar.id
        }
        let visibleSavings =
            jar.role == .savings
            ? savingsDeposits.filter {
                BudgetSummary.contains($0.openedAt, from: start, to: end, asOf: asOf)
            } : []
        let visibleFunds =
            jar.role == .investment
            ? fundHoldings.filter {
                BudgetSummary.contains($0.boughtOn, from: start, to: end, asOf: asOf)
            } : []

        return BudgetJarActivitySnapshot(
            transactions: visibleTransactions,
            savingsDeposits: visibleSavings,
            fundHoldings: visibleFunds
        )
    }
}

private struct BudgetTransactionRouting {
    private let categoryJars: [UUID: UUID?]
    private let validJarIDs: Set<UUID>
    private let fallbackJarID: UUID?

    init(jars: [BudgetJar], categories: [TransactionCategory]) {
        categoryJars = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.budgetJarID) })
        validJarIDs = Set(jars.map(\.id))
        fallbackJarID = BudgetJarRouting.fallback(in: jars)?.id
    }

    func jarID(for transaction: MoneyTransaction) -> UUID? {
        let overrideJarID = transaction.tripWorkspaceID
            .flatMap { _ in transaction.budgetJarOverrideID }
            .flatMap { validJarIDs.contains($0) ? $0 : nil }
        let mappedJarID = transaction.categoryID
            .flatMap { categoryJars[$0] ?? nil }
            .flatMap { validJarIDs.contains($0) ? $0 : nil }
        return overrideJarID ?? mappedJarID ?? fallbackJarID
    }
}

enum BudgetSummary {
    static func snapshot(
        monthContaining month: Date,
        asOf: Date,
        jars: [BudgetJar],
        categories: [TransactionCategory],
        recurringRules: [RecurringRule],
        transactions: [MoneyTransaction],
        savingsDeposits: [SavingsDeposit],
        fundHoldings: [FundHolding]
    ) -> BudgetSnapshot {
        let start = TransactionPeriod.startOfMonth(for: month)
        let end = TransactionPeriod.endOfMonth(for: month)
        let plannedIncome = recurringIncome(
            recurringRules,
            from: start,
            to: end
        )
        let receivedIncome =
            transactions
            .filter {
                $0.kind == .income && contains($0.occurredAt, from: start, to: end, asOf: asOf)
            }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let projectedIncome =
            receivedIncome
            + futureRecurringIncome(
                recurringRules,
                from: start,
                to: end,
                after: asOf
            )
        let routing = BudgetTransactionRouting(jars: jars, categories: categories)
        var usedByJar: [UUID: Decimal] = [:]

        for transaction in transactions
        where transaction.kind == .expense
            && contains(transaction.occurredAt, from: start, to: end, asOf: asOf)
        {
            guard let jarID = routing.jarID(for: transaction) else {
                continue
            }
            usedByJar[jarID, default: .zero] += transaction.amount
        }

        let savingsUsed =
            savingsDeposits
            .filter { contains($0.openedAt, from: start, to: end, asOf: asOf) }
            .reduce(Decimal.zero) { $0 + $1.principal }
        let investmentsUsed =
            fundHoldings
            .filter { contains($0.boughtOn, from: start, to: end, asOf: asOf) }
            .reduce(Decimal.zero) { $0 + $1.costBasis }

        if let jarID = jars.first(where: { $0.role == .savings })?.id {
            usedByJar[jarID, default: .zero] += savingsUsed
        }
        if let jarID = jars.first(where: { $0.role == .investment })?.id {
            usedByJar[jarID, default: .zero] += investmentsUsed
        }

        let sortedJars = jars.sorted { $0.createdAt < $1.createdAt }
        let rows = sortedJars.map { jar in
            BudgetJarSnapshot(
                jarID: jar.id,
                name: jar.name,
                allocationPercent: jar.allocationPercent,
                role: jar.role,
                symbolName: jar.symbolName,
                colorName: jar.colorName,
                planned: allocation(of: plannedIncome, percent: jar.allocationPercent),
                received: allocation(of: receivedIncome, percent: jar.allocationPercent),
                projected: allocation(of: projectedIncome, percent: jar.allocationPercent),
                used: usedByJar[jar.id, default: .zero]
            )
        }

        return BudgetSnapshot(
            month: start,
            plannedIncome: plannedIncome,
            receivedIncome: receivedIncome,
            projectedIncome: projectedIncome,
            allocationPercent: jars.reduce(Decimal.zero) { $0 + $1.allocationPercent },
            rows: rows
        )
    }

    private static func recurringIncome(
        _ rules: [RecurringRule],
        from start: Date,
        to end: Date
    ) -> Decimal {
        rules.filter { $0.kind == .income && !$0.isPaused }.reduce(Decimal.zero) {
            $0 + Decimal(occurrences(of: $1, from: start, to: end).count) * $1.amount
        }
    }

    private static func futureRecurringIncome(
        _ rules: [RecurringRule],
        from start: Date,
        to end: Date,
        after asOf: Date
    ) -> Decimal {
        rules.filter { $0.kind == .income && !$0.isPaused }.reduce(Decimal.zero) {
            let futureCount = occurrences(of: $1, from: start, to: end).count { $0 > asOf }
            return $0 + Decimal(futureCount) * $1.amount
        }
    }

    private static func occurrences(
        of rule: RecurringRule,
        from start: Date,
        to end: Date
    ) -> [Date] {
        let calendar = RecurrenceSchedule.calendar
        let lowerBound = calendar.date(byAdding: .day, value: -1, to: start)
        let finalDay = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        let upperBound = rule.endDate.map { min($0, finalDay) } ?? finalDay

        return RecurrenceSchedule.occurrences(
            frequency: rule.frequency,
            interval: rule.interval,
            anchor: rule.anchorDate,
            after: lowerBound,
            through: upperBound,
            limit: RecurringRuleDraft.maxBackfill
        )
    }

    static func contains(
        _ date: Date,
        from start: Date,
        to end: Date,
        asOf: Date
    ) -> Bool {
        date >= start && date < end && date <= asOf
    }

    private static func allocation(of amount: Decimal, percent: Decimal) -> Decimal {
        var input = amount * percent / 100
        var result = Decimal.zero
        NSDecimalRound(&result, &input, 0, .plain)
        return result
    }
}
