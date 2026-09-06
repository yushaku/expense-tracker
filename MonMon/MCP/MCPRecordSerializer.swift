import Foundation

enum MCPRecordSerializer {
    private static let dateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func serialize(_ value: CashAccount) throws -> MCPRecord {
        record(
            "CashAccount", id: value.id, sortDate: value.createdAt,
            [
                "id": uuid(value.id), "name": .string(value.name),
                "kind": .string(value.kind.rawValue),
                "openingBalance": decimal(value.openingBalance),
                "creditLimit": decimal(value.creditLimit),
                "currencyCode": .string(value.currencyCode), "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: MoneyTransaction) throws -> MCPRecord {
        var fields: [String: MCPJSONValue] = [
            "id": uuid(value.id), "kind": .string(value.kind.rawValue),
            "amount": decimal(value.amount), "occurredAt": date(value.occurredAt),
            "note": .string(value.note), "accountID": uuid(value.accountID),
            "categoryID": optionalUUID(value.categoryID),
            "sourceRuleID": optionalUUID(value.sourceRuleID),
            "currencyCode": .string(value.currencyCode), "createdAt": date(value.createdAt),
            "sourceImportID": optionalString(value.sourceImportID),
            "tripWorkspaceID": optionalUUID(value.tripWorkspaceID),
            "budgetJarOverrideID": optionalUUID(value.budgetJarOverrideID),
        ]
        fields["incomeAllocationSnapshot"] = try incomeAllocationSnapshot(
            value.incomeAllocationSnapshot)
        return record("MoneyTransaction", id: value.id, sortDate: value.occurredAt, fields)
    }

    static func serialize(_ value: AccountTransfer) throws -> MCPRecord {
        record(
            "AccountTransfer", id: value.id, sortDate: value.occurredAt,
            [
                "id": uuid(value.id), "amount": decimal(value.amount),
                "occurredAt": date(value.occurredAt), "note": .string(value.note),
                "sourceAccountID": uuid(value.sourceAccountID),
                "destinationAccountID": uuid(value.destinationAccountID),
                "currencyCode": .string(value.currencyCode), "createdAt": date(value.createdAt),
                "sourceAccountImportID": optionalString(value.sourceAccountImportID),
                "destinationAccountImportID": optionalString(value.destinationAccountImportID),
            ])
    }

    static func serialize(_ value: TransactionCategory) throws -> MCPRecord {
        record(
            "TransactionCategory", id: value.id, sortDate: value.createdAt,
            [
                "id": uuid(value.id), "name": .string(value.name),
                "kind": .string(value.kind.rawValue),
                "symbolName": .string(value.symbolName), "colorName": .string(value.colorName),
                "budgetJarID": optionalUUID(value.budgetJarID), "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: RecurringRule) throws -> MCPRecord {
        record(
            "RecurringRule", id: value.id, sortDate: value.anchorDate,
            [
                "id": uuid(value.id), "kind": .string(value.kind.rawValue),
                "amount": decimal(value.amount), "note": .string(value.note),
                "accountID": uuid(value.accountID), "categoryID": optionalUUID(value.categoryID),
                "currencyCode": .string(value.currencyCode),
                "frequency": .string(value.frequency.rawValue), "interval": .int(value.interval),
                "anchorDate": date(value.anchorDate), "endDate": optionalDate(value.endDate),
                "isPaused": .bool(value.isPaused),
                "lastGeneratedAt": optionalDate(value.lastGeneratedAt),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: BudgetJar) throws -> MCPRecord {
        record(
            "BudgetJar", id: value.id, sortDate: value.createdAt,
            [
                "id": uuid(value.id), "name": .string(value.name),
                "allocationPercent": decimal(value.allocationPercent),
                "role": .string(value.role.rawValue),
                "symbolName": .string(value.symbolName), "colorName": .string(value.colorName),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: FinancialGoal) throws -> MCPRecord {
        var fields: [String: MCPJSONValue] = [
            "id": uuid(value.id), "name": .string(value.name),
            "targetAmount": decimal(value.targetAmount),
            "earmarkedAmount": decimal(value.earmarkedAmount),
            "targetDate": date(value.targetDate),
            "monthlyContribution": decimal(value.monthlyContribution),
            "fundingJarID": optionalUUID(value.fundingJarID),
            "symbolName": .string(value.symbolName),
            "colorName": .string(value.colorName), "createdAt": date(value.createdAt),
            "archivedAt": optionalDate(value.archivedAt),
        ]
        fields["contributionHistoryData"] = try contributionHistory(value.contributionHistoryData)
        return record("FinancialGoal", id: value.id, sortDate: value.targetDate, fields)
    }

    static func serialize(_ value: TripWorkspace) throws -> MCPRecord {
        record(
            "TripWorkspace", id: value.id, sortDate: value.startedAt,
            [
                "id": uuid(value.id), "sourceGoalID": optionalUUID(value.sourceGoalID),
                "name": .string(value.name), "budgetAmount": decimal(value.budgetAmount),
                "fundingJarID": optionalUUID(value.fundingJarID),
                "symbolName": .string(value.symbolName),
                "colorName": .string(value.colorName), "status": .string(value.status.rawValue),
                "startedAt": date(value.startedAt), "completedAt": optionalDate(value.completedAt),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: SavingsDeposit) throws -> MCPRecord {
        record(
            "SavingsDeposit", id: value.id, sortDate: value.openedAt,
            [
                "id": uuid(value.id), "name": .string(value.name),
                "principal": decimal(value.principal),
                "annualInterestRate": decimal(value.annualInterestRate),
                "termMonths": .int(value.termMonths),
                "openedAt": date(value.openedAt), "currencyCode": .string(value.currencyCode),
                "createdAt": date(value.createdAt),
                "sourceAccountID": optionalUUID(value.sourceAccountID),
            ])
    }

    static func serialize(_ value: SavingsWithdrawal) throws -> MCPRecord {
        record(
            "SavingsWithdrawal", id: value.id, sortDate: value.withdrawnAt,
            [
                "id": uuid(value.id), "depositID": optionalUUID(value.depositID),
                "principal": decimal(value.principal),
                "amountReceived": decimal(value.amountReceived),
                "destinationAccountID": uuid(value.destinationAccountID),
                "withdrawnAt": date(value.withdrawnAt),
                "note": .string(value.note), "currencyCode": .string(value.currencyCode),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: FundInstrument) throws -> MCPRecord {
        record(
            "FundInstrument", id: value.id, sortDate: value.priceAsOf,
            [
                "id": uuid(value.id), "symbol": .string(value.symbol), "name": .string(value.name),
                "kind": .string(value.kind.rawValue),
                "currentPricePerUnit": decimal(value.currentPricePerUnit),
                "askPricePerUnit": decimal(value.askPricePerUnit),
                "priceAsOf": date(value.priceAsOf),
                "priceSource": .string(value.priceSource),
                "priceFetchedAt": optionalDate(value.priceFetchedAt),
                "autoQuoteEnabled": .bool(value.autoQuoteEnabled),
                "logoURL": optionalString(value.logoURL),
                "currencyCode": .string(value.currencyCode), "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: FundHolding) throws -> MCPRecord {
        record(
            "FundHolding", id: value.id, sortDate: value.purchasedAt ?? value.createdAt,
            [
                "id": uuid(value.id), "instrumentID": optionalUUID(value.instrumentID),
                "units": decimal(value.units),
                "averageCostPerUnit": decimal(value.averageCostPerUnit),
                "sourceAccountID": optionalUUID(value.sourceAccountID),
                "createdAt": date(value.createdAt),
                "purchasedAt": optionalDate(value.purchasedAt),
            ])
    }

    static func serialize(_ value: FundSale) throws -> MCPRecord {
        record(
            "FundSale", id: value.id, sortDate: value.soldAt,
            [
                "id": uuid(value.id), "holdingID": optionalUUID(value.holdingID),
                "units": decimal(value.units), "pricePerUnit": decimal(value.pricePerUnit),
                "proceedsAccountID": uuid(value.proceedsAccountID), "soldAt": date(value.soldAt),
                "note": .string(value.note), "currencyCode": .string(value.currencyCode),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: Debt) throws -> MCPRecord {
        record(
            "Debt", id: value.id, sortDate: value.openedAt,
            [
                "id": uuid(value.id), "counterparty": .string(value.counterparty),
                "direction": .string(value.direction.rawValue),
                "principal": decimal(value.principal),
                "annualInterestRate": decimal(value.annualInterestRate),
                "openedAt": date(value.openedAt),
                "dueDate": optionalDate(value.dueDate), "accountID": optionalUUID(value.accountID),
                "note": .string(value.note), "currencyCode": .string(value.currencyCode),
                "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: DebtPayment) throws -> MCPRecord {
        record(
            "DebtPayment", id: value.id, sortDate: value.occurredAt,
            [
                "id": uuid(value.id), "debtID": optionalUUID(value.debtID),
                "amount": decimal(value.amount), "occurredAt": date(value.occurredAt),
                "accountID": uuid(value.accountID), "note": .string(value.note),
                "currencyCode": .string(value.currencyCode), "createdAt": date(value.createdAt),
            ])
    }

    static func serialize(_ value: PendingTransactionCapture) throws -> MCPRecord {
        record(
            "PendingTransactionCapture", id: value.id, sortDate: value.occurredAt,
            [
                "id": uuid(value.id), "rawText": .string(value.rawText),
                "kind": .string(value.kind.rawValue),
                "amount": value.amount.map(decimal) ?? .null, "occurredAt": date(value.occurredAt),
                "note": .string(value.note), "accountID": optionalUUID(value.accountID),
                "categoryID": optionalUUID(value.categoryID),
                "issueCodes": .string(value.issueCodes),
                "createdAt": date(value.createdAt),
            ])
    }

    private static func record(
        _ type: String,
        id: UUID,
        sortDate: Date,
        _ storedFields: [String: MCPJSONValue]
    ) -> MCPRecord {
        var fields = storedFields
        fields["recordType"] = .string(type)
        return MCPRecord(recordType: type, id: id, sortDate: sortDate, fields: fields)
    }

    private static func decimal(_ value: Decimal) -> MCPJSONValue {
        .string(NSDecimalNumber(decimal: value).stringValue)
    }

    private static func date(_ value: Date) -> MCPJSONValue {
        .string(value.formatted(dateFormat))
    }

    private static func optionalDate(_ value: Date?) -> MCPJSONValue {
        value.map(date) ?? .null
    }

    private static func uuid(_ value: UUID) -> MCPJSONValue {
        .string(value.uuidString.lowercased())
    }

    private static func optionalUUID(_ value: UUID?) -> MCPJSONValue {
        value.map(uuid) ?? .null
    }

    private static func optionalString(_ value: String?) -> MCPJSONValue {
        value.map(MCPJSONValue.string) ?? .null
    }

    private static func incomeAllocationSnapshot(_ value: String?) throws -> MCPJSONValue {
        guard let value else { return .null }
        do {
            let snapshot = try IncomeAllocationSnapshotCodec.decode(value)
            return .object([
                "version": .int(snapshot.version),
                "sourceAmount": decimal(snapshot.sourceAmount),
                "capturedAt": date(snapshot.capturedAt),
                "isEstimated": .bool(snapshot.isEstimated),
                "slices": .array(
                    snapshot.slices.map { slice in
                        .object([
                            "jarID": uuid(slice.jarID),
                            "name": .string(slice.name),
                            "symbolName": .string(slice.symbolName),
                            "colorName": .string(slice.colorName),
                            "percent": decimal(slice.percent),
                            "amount": decimal(slice.amount),
                        ])
                    }),
                "unallocatedAmount": decimal(snapshot.unallocatedAmount),
            ])
        } catch {
            throw MCPToolError.decodeFailed
        }
    }

    private static func contributionHistory(_ value: Data?) throws -> MCPJSONValue {
        guard let value else { return .null }
        do {
            let entries = try JSONDecoder().decode([GoalContribution].self, from: value)
            return .array(
                entries.map { entry in
                    .object([
                        "id": uuid(entry.id),
                        "amount": decimal(entry.amount),
                        "occurredAt": date(entry.occurredAt),
                    ])
                })
        } catch {
            throw MCPToolError.decodeFailed
        }
    }
}
