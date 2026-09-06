import Foundation

enum MCPTool: String, CaseIterable, Sendable {
    case dataStatus = "monmon_data_status"
    case accounts = "monmon_list_accounts"
    case transactions = "monmon_list_transactions"
    case transfers = "monmon_list_transfers"
    case categories = "monmon_list_categories"
    case recurringRules = "monmon_list_recurring_rules"
    case budgetJars = "monmon_list_budget_jars"
    case goals = "monmon_list_goals"
    case trips = "monmon_list_trips"
    case savings = "monmon_list_savings"
    case investments = "monmon_list_investments"
    case debts = "monmon_list_debts"
    case pendingCaptures = "monmon_list_pending_captures"

    static let snapshotTools = Self.allCases.filter { $0 != .dataStatus }

    var recordTypes: Set<String> {
        switch self {
        case .dataStatus: []
        case .accounts: ["CashAccount"]
        case .transactions: ["MoneyTransaction"]
        case .transfers: ["AccountTransfer"]
        case .categories: ["TransactionCategory"]
        case .recurringRules: ["RecurringRule"]
        case .budgetJars: ["BudgetJar"]
        case .goals: ["FinancialGoal"]
        case .trips: ["TripWorkspace"]
        case .savings: ["SavingsDeposit", "SavingsWithdrawal"]
        case .investments: ["FundInstrument", "FundHolding", "FundSale"]
        case .debts: ["Debt", "DebtPayment"]
        case .pendingCaptures: ["PendingTransactionCapture"]
        }
    }

    var filterKeys: Set<String> {
        let common: Set<String> = [
            "limit", "cursor", "id", "ids", "createdAtFrom", "createdAtTo", "dateFrom", "dateTo",
        ]
        let specific: Set<String>
        switch self {
        case .dataStatus:
            specific = []
        case .accounts:
            specific = ["kind"]
        case .transactions:
            specific = [
                "kind", "accountID", "categoryID", "sourceRuleID", "tripWorkspaceID",
                "budgetJarOverrideID",
            ]
        case .transfers:
            specific = ["sourceAccountID", "destinationAccountID"]
        case .categories:
            specific = ["kind", "budgetJarID"]
        case .recurringRules:
            specific = ["kind", "frequency", "accountID", "categoryID"]
        case .budgetJars:
            specific = ["role"]
        case .goals:
            specific = ["fundingJarID"]
        case .trips:
            specific = ["status", "sourceGoalID", "fundingJarID"]
        case .savings:
            specific = ["recordType", "depositID", "sourceAccountID", "destinationAccountID"]
        case .investments:
            specific = [
                "recordType", "kind", "instrumentID", "sourceAccountID", "holdingID",
                "proceedsAccountID",
            ]
        case .debts:
            specific = ["recordType", "direction", "debtID", "accountID"]
        case .pendingCaptures:
            specific = ["kind", "accountID", "categoryID"]
        }
        return common.union(specific)
    }
}

struct MCPQuery: Equatable, Sendable {
    static let defaultLimit = 50
    static let maximumLimit = 200

    var limit = defaultLimit
    var cursor: String?
    var ids: Set<UUID>?
    var createdAtFrom: Date?
    var createdAtTo: Date?
    var dateFrom: Date?
    var dateTo: Date?
    var fieldFilters: [String: String] = [:]

    static func parse(
        arguments: [String: MCPJSONValue],
        for tool: MCPTool
    ) throws -> MCPQuery {
        guard Set(arguments.keys).isSubset(of: tool.filterKeys) else {
            throw MCPToolError.invalidArgument
        }

        var query = MCPQuery()
        if let value = arguments["limit"] {
            guard case .int(let limit) = value, (1...maximumLimit).contains(limit) else {
                throw MCPToolError.invalidArgument
            }
            query.limit = limit
        }
        if let value = arguments["cursor"] {
            guard case .string(let cursor) = value, !cursor.isEmpty else {
                throw MCPToolError.invalidArgument
            }
            query.cursor = cursor
        }

        var ids = Set<UUID>()
        if let value = arguments["id"] {
            guard case .string(let raw) = value, let id = UUID(uuidString: raw) else {
                throw MCPToolError.invalidArgument
            }
            ids.insert(id)
        }
        if let value = arguments["ids"] {
            guard case .array(let values) = value else { throw MCPToolError.invalidArgument }
            for value in values {
                guard case .string(let raw) = value, let id = UUID(uuidString: raw) else {
                    throw MCPToolError.invalidArgument
                }
                ids.insert(id)
            }
        }
        query.ids = arguments["id"] == nil && arguments["ids"] == nil ? nil : ids

        query.createdAtFrom = try parseDate(arguments["createdAtFrom"])
        query.createdAtTo = try parseDate(arguments["createdAtTo"])
        query.dateFrom = try parseDate(arguments["dateFrom"])
        query.dateTo = try parseDate(arguments["dateTo"])
        guard validRange(query.createdAtFrom, query.createdAtTo),
            validRange(query.dateFrom, query.dateTo)
        else {
            throw MCPToolError.invalidArgument
        }

        let reserved: Set<String> = [
            "limit", "cursor", "id", "ids", "createdAtFrom", "createdAtTo", "dateFrom", "dateTo",
        ]
        for (key, value) in arguments where !reserved.contains(key) {
            guard case .string(let raw) = value, !raw.isEmpty else {
                throw MCPToolError.invalidArgument
            }
            let normalized = normalizedFilter(raw, key: key)
            guard validFilterValue(normalized, key: key, tool: tool) else {
                throw MCPToolError.invalidArgument
            }
            query.fieldFilters[key] = normalized
        }
        return query
    }

    private static func parseDate(_ value: MCPJSONValue?) throws -> Date? {
        guard let value else { return nil }
        guard case .string(let raw) = value else { throw MCPToolError.invalidArgument }
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let whole = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        guard let date = (try? fractional.parse(raw)) ?? (try? whole.parse(raw)) else {
            throw MCPToolError.invalidArgument
        }
        return date
    }

    private static func validRange(_ lower: Date?, _ upper: Date?) -> Bool {
        guard let lower, let upper else { return true }
        return lower <= upper
    }

    private static func normalizedFilter(_ value: String, key: String) -> String {
        key.hasSuffix("ID") ? value.lowercased() : value
    }

    private static func validFilterValue(_ value: String, key: String, tool: MCPTool) -> Bool {
        if key.hasSuffix("ID") {
            return UUID(uuidString: value) != nil
        }
        let allowed: Set<String>?
        switch (tool, key) {
        case (.accounts, "kind"):
            allowed = ["normal", "credit"]
        case (.transactions, "kind"), (.categories, "kind"),
            (.recurringRules, "kind"), (.pendingCaptures, "kind"):
            allowed = ["income", "expense"]
        case (.recurringRules, "frequency"):
            allowed = ["daily", "weekly", "monthly", "yearly"]
        case (.budgetJars, "role"):
            allowed = ["custom", "investment", "savings"]
        case (.trips, "status"):
            allowed = ["active", "completed"]
        case (.savings, "recordType"):
            allowed = ["SavingsDeposit", "SavingsWithdrawal"]
        case (.investments, "recordType"):
            allowed = ["FundInstrument", "FundHolding", "FundSale"]
        case (.investments, "kind"):
            allowed = ["fund", "etf", "gold"]
        case (.debts, "recordType"):
            allowed = ["Debt", "DebtPayment"]
        case (.debts, "direction"):
            allowed = ["borrowed", "lent"]
        default:
            allowed = nil
        }
        return allowed?.contains(value) ?? true
    }
}

struct MCPPageResult: Equatable, Sendable {
    let records: [MCPRecord]
    let nextCursor: String?
}

enum MCPPaginator {
    private struct Cursor: Codable {
        let version: Int
        let tool: String
        let sortTime: TimeInterval
        let id: String
        let recordType: String
    }

    static func page(
        records: [MCPRecord],
        query: MCPQuery,
        tool: MCPTool
    ) throws -> MCPPageResult {
        var filtered = try records.filter { try matches($0, query: query) }
        filtered.sort(by: orderedBefore)

        if let rawCursor = query.cursor {
            let cursor = try decode(rawCursor, for: tool)
            filtered = filtered.filter { isAfter($0, cursor: cursor) }
        }

        let selected = Array(filtered.prefix(query.limit))
        let nextCursor: String?
        if filtered.count > selected.count, let last = selected.last {
            nextCursor = try encode(last, for: tool)
        } else {
            nextCursor = nil
        }
        return MCPPageResult(records: selected, nextCursor: nextCursor)
    }

    private static func matches(_ record: MCPRecord, query: MCPQuery) throws -> Bool {
        if let ids = query.ids, !ids.contains(record.id) { return false }
        if let createdAtFrom = query.createdAtFrom {
            guard let createdAt = try fieldDate(record, key: "createdAt"),
                createdAt >= createdAtFrom
            else { return false }
        }
        if let createdAtTo = query.createdAtTo {
            guard let createdAt = try fieldDate(record, key: "createdAt"), createdAt <= createdAtTo
            else { return false }
        }
        if let dateFrom = query.dateFrom, record.sortDate < dateFrom { return false }
        if let dateTo = query.dateTo, record.sortDate > dateTo { return false }
        for (key, wanted) in query.fieldFilters {
            guard record.fields[key]?.stringValue == wanted else { return false }
        }
        return true
    }

    private static func fieldDate(_ record: MCPRecord, key: String) throws -> Date? {
        guard let value = record.fields[key] else { return nil }
        guard case .string(let raw) = value else { throw MCPToolError.decodeFailed }
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let whole = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
        guard let result = (try? fractional.parse(raw)) ?? (try? whole.parse(raw)) else {
            throw MCPToolError.decodeFailed
        }
        return result
    }

    private static func orderedBefore(_ lhs: MCPRecord, _ rhs: MCPRecord) -> Bool {
        if lhs.sortDate != rhs.sortDate { return lhs.sortDate > rhs.sortDate }
        let leftID = lhs.id.uuidString.lowercased()
        let rightID = rhs.id.uuidString.lowercased()
        if leftID != rightID { return leftID < rightID }
        return lhs.recordType < rhs.recordType
    }

    private static func isAfter(_ record: MCPRecord, cursor: Cursor) -> Bool {
        let cursorDate = Date(timeIntervalSinceReferenceDate: cursor.sortTime)
        if record.sortDate != cursorDate { return record.sortDate < cursorDate }
        let id = record.id.uuidString.lowercased()
        if id != cursor.id { return id > cursor.id }
        return record.recordType > cursor.recordType
    }

    private static func encode(_ record: MCPRecord, for tool: MCPTool) throws -> String {
        let cursor = Cursor(
            version: 1,
            tool: tool.rawValue,
            sortTime: record.sortDate.timeIntervalSinceReferenceDate,
            id: record.id.uuidString.lowercased(),
            recordType: record.recordType
        )
        let data = try JSONEncoder().encode(cursor)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ raw: String, for tool: MCPTool) throws -> Cursor {
        var base64 = raw.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard
            let data = Data(base64Encoded: base64),
            let cursor = try? JSONDecoder().decode(Cursor.self, from: data),
            cursor.version == 1,
            cursor.tool == tool.rawValue,
            UUID(uuidString: cursor.id) != nil,
            cursor.sortTime.isFinite
        else {
            throw MCPToolError.invalidCursor
        }
        return cursor
    }
}
