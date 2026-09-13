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
