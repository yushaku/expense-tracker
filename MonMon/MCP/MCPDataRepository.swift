import SwiftData

@MainActor
final class MCPDataRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func records(for tool: MCPTool) throws -> [MCPRecord] {
        switch tool {
        case .dataStatus:
            return []
        case .accounts:
            return try context.fetch(FetchDescriptor<CashAccount>()).map(
                MCPRecordSerializer.serialize)
        case .transactions:
            return try context.fetch(FetchDescriptor<MoneyTransaction>()).map(
                MCPRecordSerializer.serialize)
        case .transfers:
            return try context.fetch(FetchDescriptor<AccountTransfer>()).map(
                MCPRecordSerializer.serialize)
        case .categories:
            return try context.fetch(FetchDescriptor<TransactionCategory>()).map(
                MCPRecordSerializer.serialize)
        case .recurringRules:
            return try context.fetch(FetchDescriptor<RecurringRule>()).map(
                MCPRecordSerializer.serialize)
        case .budgetJars:
            return try context.fetch(FetchDescriptor<BudgetJar>()).map(
                MCPRecordSerializer.serialize)
        case .goals:
            return try context.fetch(FetchDescriptor<FinancialGoal>()).map(
                MCPRecordSerializer.serialize)
        case .trips:
            return try context.fetch(FetchDescriptor<TripWorkspace>()).map(
                MCPRecordSerializer.serialize)
        case .savings:
            return try context.fetch(FetchDescriptor<SavingsDeposit>()).map(
                MCPRecordSerializer.serialize)
                + context.fetch(FetchDescriptor<SavingsWithdrawal>()).map(
                    MCPRecordSerializer.serialize)
        case .investments:
            return try context.fetch(FetchDescriptor<FundInstrument>()).map(
                MCPRecordSerializer.serialize)
                + context.fetch(FetchDescriptor<FundHolding>()).map(MCPRecordSerializer.serialize)
                + context.fetch(FetchDescriptor<FundSale>()).map(MCPRecordSerializer.serialize)
        case .debts:
            return try context.fetch(FetchDescriptor<Debt>()).map(MCPRecordSerializer.serialize)
                + context.fetch(FetchDescriptor<DebtPayment>()).map(MCPRecordSerializer.serialize)
        case .pendingCaptures:
            return try context.fetch(FetchDescriptor<PendingTransactionCapture>()).map(
                MCPRecordSerializer.serialize)
        }
    }
}
