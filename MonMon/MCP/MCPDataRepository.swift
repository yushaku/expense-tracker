import Foundation
import SwiftData

@MainActor
final class MCPDataRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func records(for tool: MCPTool, query: MCPQuery = MCPQuery()) throws -> [MCPRecord] {
        let hasIDs = query.ids != nil
        let ids = Array(query.ids ?? [])
        let createdFrom = query.createdAtFrom ?? .distantPast
        let createdTo = query.createdAtTo ?? .distantFuture
        let dateFrom = query.dateFrom ?? .distantPast
        let dateTo = query.dateTo ?? .distantFuture
        switch tool {
        case .summary:
            return try summary(query: query)
        case .dataStatus:
            return []
        case .accounts:
            return try context.fetch(
                FetchDescriptor<CashAccount>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.createdAt >= dateFrom && record.createdAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .transactions:
            return try context.fetch(
                FetchDescriptor<MoneyTransaction>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.occurredAt >= dateFrom && record.occurredAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .transfers:
            return try context.fetch(
                FetchDescriptor<AccountTransfer>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.occurredAt >= dateFrom && record.occurredAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .categories:
            return try context.fetch(
                FetchDescriptor<TransactionCategory>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.createdAt >= dateFrom && record.createdAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .recurringRules:
            return try context.fetch(
                FetchDescriptor<RecurringRule>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.anchorDate >= dateFrom && record.anchorDate <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .budgetJars:
            return try context.fetch(
                FetchDescriptor<BudgetJar>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.createdAt >= dateFrom && record.createdAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .goals:
            return try context.fetch(
                FetchDescriptor<FinancialGoal>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.targetDate >= dateFrom && record.targetDate <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .trips:
            return try context.fetch(
                FetchDescriptor<TripWorkspace>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.startedAt >= dateFrom && record.startedAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .savings:
            return try context.fetch(
                FetchDescriptor<SavingsDeposit>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.openedAt >= dateFrom && record.openedAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<SavingsWithdrawal>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.withdrawnAt >= dateFrom && record.withdrawnAt <= dateTo
                        })
                ).map(
                    MCPRecordSerializer.serialize)
        case .investments:
            return try context.fetch(
                FetchDescriptor<FundInstrument>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.priceAsOf >= dateFrom && record.priceAsOf <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<FundHolding>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && (record.purchasedAt ?? record.createdAt) >= dateFrom
                                && (record.purchasedAt ?? record.createdAt) <= dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<FundSale>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.soldAt >= dateFrom && record.soldAt <= dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
        case .debts:
            return try context.fetch(
                FetchDescriptor<Debt>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.openedAt >= dateFrom && record.openedAt <= dateTo
                    })
            ).map(MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<DebtPayment>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.occurredAt >= dateFrom && record.occurredAt <= dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
        case .pendingCaptures:
            return try context.fetch(
                FetchDescriptor<PendingTransactionCapture>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.occurredAt >= dateFrom && record.occurredAt <= dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        }
    }
}

// Aggregation stays in the store context: no transaction pages are sent to the agent.
extension MCPDataRepository {
    private struct SummaryAmount {
        var income = Decimal.zero
        var expense = Decimal.zero
        var count = 0

        mutating func add(_ amount: Decimal, income isIncome: Bool) throws {
            if isIncome {
                income = try sum(income, amount)
            } else {
                expense = try sum(expense, amount)
            }
            count += 1
        }

        func fields(currency: String) throws -> [String: MCPJSONValue] {
            [
                "currencyCode": .string(currency), "income": decimal(income),
                "expense": decimal(expense), "net": decimal(try sum(income, -expense)),
                "transactionCount": .int(count),
            ]
        }

        private func decimal(_ value: Decimal) -> MCPJSONValue {
            .string(NSDecimalNumber(decimal: value).stringValue)
        }

        private func sum(_ left: Decimal, _ right: Decimal) throws -> Decimal {
            var lhs = left
            var rhs = right
            var result = Decimal.zero
            guard NSDecimalAdd(&result, &lhs, &rhs, .plain) == .noError else {
                throw MCPToolError.decodeFailed
            }
            return result
        }
    }

    private struct ExpenseGroup: Hashable {
        let id: UUID?
        let currency: String
    }

    private func summary(query: MCPQuery) throws -> [MCPRecord] {
        guard let from = query.dateFrom, let to = query.dateTo else {
            throw MCPToolError.invalidArgument
        }
        let transactions = try context.fetch(
            FetchDescriptor<MoneyTransaction>(
                predicate: #Predicate { $0.occurredAt >= from && $0.occurredAt < to }))
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let jars = try context.fetch(FetchDescriptor<BudgetJar>())
        let routing = BudgetTransactionRouting(jars: jars, categories: categories)
        let groupBy = query.fieldFilters["groupBy"] ?? "none"
        let accountID = query.fieldFilters["accountID"].flatMap(UUID.init(uuidString:))
        let categoryID = query.fieldFilters["categoryID"].flatMap(UUID.init(uuidString:))
        let jarID = query.fieldFilters["budgetJarID"].flatMap(UUID.init(uuidString:))
        var totals: [String: SummaryAmount] = [:]
        var groups: [ExpenseGroup: SummaryAmount] = [:]
        for transaction in transactions {
            if let accountID, transaction.accountID != accountID { continue }
            if let categoryID, transaction.categoryID != categoryID { continue }
            let routedJar = routing.jarID(for: transaction)
            if let jarID, transaction.kind != .expense || routedJar != jarID { continue }
            guard !transaction.amount.isNaN, transaction.amount >= 0,
                !transaction.currencyCode.isEmpty
            else { throw MCPToolError.decodeFailed }
            let currency = transaction.currencyCode
            try totals[currency, default: SummaryAmount()].add(
                transaction.amount,
                income: transaction.kind == .income)
            if groupBy != "none", transaction.kind == .expense {
                let id = groupBy == "category" ? transaction.categoryID : routedJar
                try groups[ExpenseGroup(id: id, currency: currency), default: SummaryAmount()]
                    .add(transaction.amount, income: false)
            }
        }
        let names = Dictionary(
            firstWins: groupBy == "category"
                ? categories.map { ($0.id, $0.name) } : jars.map { ($0.id, $0.name) })
        let groupRows = try groups.keys.sorted {
            if $0.currency != $1.currency { return $0.currency < $1.currency }
            return ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "")
        }.map { key -> MCPJSONValue in
            var fields = try groups[key, default: SummaryAmount()].fields(currency: key.currency)
            fields["groupID"] = key.id.map { .string($0.uuidString.lowercased()) } ?? .null
            fields["name"] = key.id.flatMap { names[$0] }.map(MCPJSONValue.string) ?? .null
            return .object(fields)
        }
        let fields: [String: MCPJSONValue] = [
            "recordType": .string("Summary"),
            "dateFrom": .string(from.formatted(.iso8601)),
            "dateTo": .string(to.formatted(.iso8601)),
            "groupBy": .string(groupBy),
            "totals": .array(
                try totals.keys.sorted().map {
                    .object(try totals[$0, default: SummaryAmount()].fields(currency: $0))
                }),
            "expenseGroups": .array(groupRows),
        ]
        return [
            MCPRecord(
                recordType: "Summary",
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                sortDate: from, fields: fields)
        ]
    }
}
