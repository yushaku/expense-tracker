import Foundation
import SwiftData

@MainActor
final class MCPDataRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func records(for tool: MCPTool, query: MCPQuery = MCPQuery()) throws -> [MCPRecord] {
        let records = try rawRecords(for: tool, query: query)
        return try enriched(records)
    }

    private func rawRecords(for tool: MCPTool, query: MCPQuery) throws -> [MCPRecord] {
        let hasIDs = query.ids != nil
        let ids = Array(query.ids ?? [])
        let createdFrom = query.createdAtFrom ?? .distantPast
        let createdTo = query.createdAtTo ?? .distantFuture
        let dateFrom = query.dateFrom ?? .distantPast
        let dateTo = query.dateTo ?? .distantFuture
        switch tool {
        case .summary:
            return try summary(query: query)
        case .accountBalances:
            return try accountBalances(query: query)
        case .portfolio:
            return try portfolio(query: query)
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
                            && record.occurredAt >= dateFrom && record.occurredAt < dateTo
                    })
            ).map {
                try MCPRecordSerializer.serialize(
                    $0, includeAllocationSlices: query.includes.contains("allocationSlices"))
            }
        case .transfers:
            return try context.fetch(
                FetchDescriptor<AccountTransfer>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.occurredAt >= dateFrom && record.occurredAt < dateTo
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
                            && record.anchorDate >= dateFrom && record.anchorDate < dateTo
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
                            && record.targetDate >= dateFrom && record.targetDate < dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .trips:
            return try context.fetch(
                FetchDescriptor<TripWorkspace>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.startedAt >= dateFrom && record.startedAt < dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        case .savings:
            return try context.fetch(
                FetchDescriptor<SavingsDeposit>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.openedAt >= dateFrom && record.openedAt < dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<SavingsWithdrawal>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.withdrawnAt >= dateFrom && record.withdrawnAt < dateTo
                        })
                ).map(
                    MCPRecordSerializer.serialize)
        case .investments:
            return try context.fetch(
                FetchDescriptor<FundInstrument>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.priceAsOf >= dateFrom && record.priceAsOf < dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<FundHolding>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && (record.purchasedAt ?? record.createdAt) >= dateFrom
                                && (record.purchasedAt ?? record.createdAt) < dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<FundSale>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.soldAt >= dateFrom && record.soldAt < dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
        case .debts:
            return try context.fetch(
                FetchDescriptor<Debt>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.openedAt >= dateFrom && record.openedAt < dateTo
                    })
            ).map(MCPRecordSerializer.serialize)
                + context.fetch(
                    FetchDescriptor<DebtPayment>(
                        predicate: #Predicate { record in
                            (!hasIDs || ids.contains(record.id))
                                && record.createdAt >= createdFrom && record.createdAt <= createdTo
                                && record.occurredAt >= dateFrom && record.occurredAt < dateTo
                        })
                ).map(MCPRecordSerializer.serialize)
        case .pendingCaptures:
            return try context.fetch(
                FetchDescriptor<PendingTransactionCapture>(
                    predicate: #Predicate { record in
                        (!hasIDs || ids.contains(record.id))
                            && record.createdAt >= createdFrom && record.createdAt <= createdTo
                            && record.occurredAt >= dateFrom && record.occurredAt < dateTo
                    })
            ).map(
                MCPRecordSerializer.serialize)
        }
    }

    private func enriched(_ records: [MCPRecord]) throws -> [MCPRecord] {
        let accountNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<CashAccount>()).map { ($0.id, $0.name) })
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let categoryNames = Dictionary(firstWins: categories.map { ($0.id, $0.name) })
        let categoryJarIDs = Dictionary(
            firstWins: categories.compactMap { category in
                category.budgetJarID.map { (category.id, $0) }
            })
        let jarNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<BudgetJar>()).map { ($0.id, $0.name) })
        let instrumentNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<FundInstrument>()).map {
                ($0.id, $0.name)
            })
        let depositNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<SavingsDeposit>()).map {
                ($0.id, $0.name)
            })
        let goalNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<FinancialGoal>()).map { ($0.id, $0.name) })
        let tripNames = Dictionary(
            firstWins: try context.fetch(FetchDescriptor<TripWorkspace>()).map { ($0.id, $0.name) })
        let lookups: [(String, String, [UUID: String])] = [
            ("accountID", "accountName", accountNames),
            ("sourceAccountID", "sourceAccountName", accountNames),
            ("destinationAccountID", "destinationAccountName", accountNames),
            ("proceedsAccountID", "proceedsAccountName", accountNames),
            ("categoryID", "categoryName", categoryNames),
            ("budgetJarID", "budgetJarName", jarNames),
            ("budgetJarOverrideID", "jarName", jarNames),
            ("fundingJarID", "fundingJarName", jarNames),
            ("instrumentID", "instrumentName", instrumentNames),
            ("depositID", "depositName", depositNames),
            ("sourceGoalID", "sourceGoalName", goalNames),
            ("tripWorkspaceID", "tripName", tripNames),
        ]
        return records.map { record in
            var fields = record.fields
            for (idKey, nameKey, names) in lookups {
                guard let raw = fields[idKey]?.stringValue, let id = UUID(uuidString: raw) else {
                    continue
                }
                fields[nameKey] = names[id].map(MCPJSONValue.string) ?? .null
            }
            if record.recordType == "MoneyTransaction", fields["jarName"]?.stringValue == nil,
                let rawCategoryID = fields["categoryID"]?.stringValue,
                let categoryID = UUID(uuidString: rawCategoryID),
                let jarID = categoryJarIDs[categoryID]
            {
                fields["jarName"] = jarNames[jarID].map(MCPJSONValue.string) ?? .null
            }
            return MCPRecord(
                recordType: record.recordType, id: record.id, sortDate: record.sortDate,
                fields: fields)
        }
    }
}

// Aggregation stays in the store context: no transaction pages are sent to the agent.
extension MCPDataRepository {
    private func accountBalances(query: MCPQuery) throws -> [MCPRecord] {
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let deposits = try context.fetch(FetchDescriptor<SavingsDeposit>())
        let withdrawals = try context.fetch(FetchDescriptor<SavingsWithdrawal>())
        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let debts = try context.fetch(FetchDescriptor<Debt>())
        let payments = try context.fetch(FetchDescriptor<DebtPayment>())
        let sales = try context.fetch(FetchDescriptor<FundSale>())
        let instrumentByID = Dictionary(firstWins: instruments.map { ($0.id, $0) })
        let asOf = Date.now
        let wantedAccountID = query.fieldFilters["accountID"].flatMap(UUID.init(uuidString:))
        let wantedKind = query.fieldFilters["kind"]

        return accounts.compactMap { account in
            guard wantedAccountID == nil || wantedAccountID == account.id,
                wantedKind == nil || wantedKind == account.kind.rawValue
            else { return nil }
            let unattributedSavings = deposits.reduce(Decimal.zero) {
                $1.sourceAccountID == nil && $1.currencyCode == account.currencyCode
                    ? $0 + $1.principal : $0
            }
            let unattributedInvestments = holdings.reduce(Decimal.zero) { total, holding in
                guard holding.sourceAccountID == nil,
                    let instrumentID = holding.instrumentID,
                    instrumentByID[instrumentID]?.currencyCode == account.currencyCode
                else { return total }
                return total + holding.costBasis
            }
            let currentBalance = CashBalanceSummary.available(
                for: account, deposits: deposits, holdings: holdings, withdrawals: withdrawals,
                transactions: transactions, transfers: transfers, debts: debts, payments: payments,
                sales: sales)
            let reconciled = unattributedSavings == 0 && unattributedInvestments == 0
            var fields: [String: MCPJSONValue] = [
                "recordType": .string("AccountBalance"),
                "accountID": .string(account.id.uuidString.lowercased()),
                "name": .string(account.name),
                "kind": .string(account.kind.rawValue),
                "currencyCode": .string(account.currencyCode),
                "currentBalance": mcpDecimal(currentBalance),
                "availableCredit": account.kind == .credit
                    ? mcpDecimal(
                        CashBalanceSummary.availableCredit(
                            limit: account.creditLimit, currentBalance: currentBalance))
                    : .null,
                "asOf": mcpDate(asOf),
                "isReconciled": .bool(reconciled),
                "unattributedSavingsPrincipal": mcpDecimal(unattributedSavings),
                "unattributedInvestmentCostBasis": mcpDecimal(unattributedInvestments),
            ]
            if !reconciled {
                fields["reconciliationIssues"] = .array([
                    .string(
                        "Savings or investments without sourceAccountID cannot be assigned to this account."
                    )
                ])
            }
            return MCPRecord(
                recordType: "AccountBalance", id: account.id, sortDate: asOf, fields: fields)
        }
    }

    private func portfolio(query: MCPQuery) throws -> [MCPRecord] {
        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        let sales = try context.fetch(FetchDescriptor<FundSale>())
        let wantedInstrumentID = query.fieldFilters["instrumentID"].flatMap(
            UUID.init(uuidString:))
        let wantedKind = query.fieldFilters["kind"]
        let groups = FundSummary.groups(
            holdings: holdings, instruments: instruments, sales: sales
        ).filter { group in
            (wantedInstrumentID == nil || group.instrumentID == wantedInstrumentID)
                && (wantedKind == nil || group.instrument?.kind.rawValue == wantedKind)
        }
        let positions: [MCPJSONValue] = groups.map { group in
            .object([
                "instrumentID": group.instrumentID.map {
                    .string($0.uuidString.lowercased())
                } ?? .null,
                "name": .string(group.name),
                "symbol": .string(group.symbol),
                "kind": group.instrument.map { .string($0.kind.rawValue) } ?? .null,
                "currencyCode": group.instrument.map { .string($0.currencyCode) } ?? .null,
                "units": mcpDecimal(group.units),
                "costBasis": mcpDecimal(group.costBasis),
                "marketValue": mcpDecimal(group.marketValue),
                "unrealizedProfitLoss": mcpDecimal(group.unrealizedProfitLoss),
                "realizedProfitLoss": mcpDecimal(group.realizedProfitLoss),
                "totalProfitLoss": mcpDecimal(
                    group.unrealizedProfitLoss + group.realizedProfitLoss),
                "currentPricePerUnit": mcpDecimal(group.pricePerUnit),
                "priceAsOf": group.instrument.map { mcpDate($0.priceAsOf) } ?? .null,
                "isPriced": .bool(group.instrument != nil),
            ])
        }
        let totals = Dictionary(grouping: groups) { $0.instrument?.currencyCode ?? "UNKNOWN" }
            .keys.sorted().map { currency -> MCPJSONValue in
                let values = groups.filter {
                    ($0.instrument?.currencyCode ?? "UNKNOWN") == currency
                }
                let cost = values.reduce(Decimal.zero) { $0 + $1.costBasis }
                let market = values.reduce(Decimal.zero) { $0 + $1.marketValue }
                let realized = values.reduce(Decimal.zero) { $0 + $1.realizedProfitLoss }
                return .object([
                    "currencyCode": .string(currency),
                    "costBasis": mcpDecimal(cost),
                    "marketValue": mcpDecimal(market),
                    "unrealizedProfitLoss": mcpDecimal(market - cost),
                    "realizedProfitLoss": mcpDecimal(realized),
                    "totalProfitLoss": mcpDecimal(market - cost + realized),
                ])
            }
        let unattributedCount = groups.flatMap(\.holdings).filter {
            $0.sourceAccountID == nil
        }.count
        let asOf = Date.now
        return [
            MCPRecord(
                recordType: "Portfolio",
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                sortDate: asOf,
                fields: [
                    "recordType": .string("Portfolio"), "asOf": mcpDate(asOf),
                    "totals": .array(totals), "positions": .array(positions),
                    "positionCount": .int(groups.count),
                    "unattributedSourceHoldingCount": .int(unattributedCount),
                    "isReconciled": .bool(unattributedCount == 0),
                ])
        ]
    }

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
        var fields: [String: MCPJSONValue] = [
            "recordType": .string("Summary"),
            "dateFrom": .string(from.formatted(.iso8601)),
            "dateTo": .string(to.formatted(.iso8601)),
            "groupBy": .string(groupBy),
            "totals": .array(
                try totals.keys.sorted().map {
                    .object(try totals[$0, default: SummaryAmount()].fields(currency: $0))
                }),
            "excludes": .array(["transfers", "savings", "investments"].map(MCPJSONValue.string)),
        ]
        if groupBy != "none" { fields["expenseGroups"] = .array(groupRows) }
        return [
            MCPRecord(
                recordType: "Summary",
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                sortDate: from, fields: fields)
        ]
    }
}

private func mcpDecimal(_ value: Decimal) -> MCPJSONValue {
    .string(NSDecimalNumber(decimal: value).stringValue)
}

private func mcpDate(_ value: Date) -> MCPJSONValue {
    .string(value.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
}
