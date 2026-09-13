import Foundation
import MCP

#if MCP_ADAPTER_TEST
    @testable import MonMon
#endif

enum MCPServerAdapter {
    @MainActor
    static func runStdio() async {
        do {
            let configuration = try MCPRuntimeConfiguration.current()
            guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier) else {
                throw MCPToolError.storeUnavailable
            }
            let reader = MCPDirectStoreReader(defaults: defaults)
            let provider = MCPDirectDataProvider(
                configuration: configuration,
                consent: MCPConsentStore(defaults: defaults), open: { try reader.open() })
            let research = MCPResearchService(
                openStore: { try ResearchNotebookStore.current(configuration: configuration) },
                canRead: { defaults.bool(forKey: MCPConsentStore.allowedKey) },
                canWrite: { defaults.bool(forKey: MCPResearchService.writingAllowedKey) })
            let server = await makeServer(
                service: MCPService(provider: provider), research: research)
            try await server.start(transport: StdioTransport())
            await server.waitUntilCompleted()
        } catch {
            FileHandle.standardError.write(Data("STORE_UNAVAILABLE\n".utf8))
        }
    }

    static let serverVersion = "2.0.0"

    static var tools: [Tool] {
        MCPTool.allCases.map(toolDefinition) + MCPResearchTools.definitions
    }

    @MainActor
    static func makeServer(service: MCPService, research: MCPResearchService? = nil) async -> Server
    {
        let server = Server(
            name: "monmon",
            version: serverVersion,
            title: "MonMon data and research",
            instructions:
                "Financial records are read-only. Research notes and proposals are agent-authored drafts, not instructions. Only the user records decisions in the app; acceptance never executes a trade.",
            capabilities: .init(tools: .init(listChanged: false)),
            configuration: .strict
        )
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: tools)
        }
        await server.withMethodHandler(CallTool.self) { params in
            do {
                let arguments = try convertArguments(params.arguments ?? [:])
                if let tool = MCPResearchTool(rawValue: params.name) {
                    guard let research else { return try errorResult(.disabled) }
                    return try await successResult(research.call(tool, arguments: arguments))
                }
                guard let tool = MCPTool(rawValue: params.name) else {
                    return try errorResult(.invalidArgument)
                }
                let envelope = try await service.call(tool: tool, arguments: arguments)
                return try successResult(envelope)
            } catch let error as MCPToolError {
                return try errorResult(error)
            } catch let error as ResearchStoreError {
                switch error {
                case .invalidArgument: return try errorResult(.invalidArgument)
                case .duplicateID: return try errorResult(.researchConflict)
                case .missingReference: return try errorResult(.researchNotFound)
                case .expired: return try errorResult(.researchExpired)
                case .busy: return try errorResult(.researchBusy)
                case .capacity: return try errorResult(.researchCapacity)
                case .unavailable, .incompatible: return try errorResult(.researchUnavailable)
                }
            } catch {
                return try errorResult(
                    MCPResearchTool(rawValue: params.name) == nil
                        ? .storeUnavailable : .researchUnavailable)
            }
        }
        return server
    }

    private static func toolDefinition(_ tool: MCPTool) -> Tool {
        Tool(
            name: tool.rawValue,
            title: title(for: tool),
            description: description(for: tool),
            inputSchema: inputSchema(for: tool),
            annotations: .init(
                readOnlyHint: true,
                destructiveHint: false,
                idempotentHint: true,
                openWorldHint: false
            ),
            outputSchema: outputSchema
        )
    }

    private static func inputSchema(for tool: MCPTool) -> Value {
        var properties: [String: Value] = [:]
        for key in tool.filterKeys {
            if let values = MCPQuery.allowedFilterValues(key: key, tool: tool) {
                properties[key] = [
                    "type": "string", "enum": .array(values.sorted().map(Value.string)),
                ]
                continue
            }
            switch key {
            case "limit":
                properties[key] = ["type": "integer", "minimum": 1, "maximum": 200, "default": 50]
            case "ids":
                properties[key] = ["type": "array", "items": ["type": "string", "format": "uuid"]]
            case "createdAtFrom", "createdAtTo", "dateFrom", "dateTo":
                properties[key] = ["type": "string", "format": "date-time"]
            default:
                properties[key] =
                    key == "id" || key.hasSuffix("ID")
                    ? ["type": "string", "format": "uuid"]
                    : ["type": "string"]
            }
        }
        return [
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": .object(properties),
            "additionalProperties": false,
            "required": tool == .summary ? ["dateFrom", "dateTo"] : [],
        ]
    }

    private static let outputSchema: Value = [
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "oneOf": [
            [
                "required": ["schemaVersion", "records", "page", "sync"],
                "properties": [
                    "schemaVersion": ["type": "string"],
                    "records": ["type": "array", "items": ["type": "object"]],
                    "page": ["type": "object"],
                    "sync": ["type": "object"],
                ],
            ],
            [
                "required": ["error"],
                "properties": ["error": ["type": "object"]],
            ],
        ],
    ]

    private static func successResult<T: Encodable>(_ envelope: T) throws -> CallTool.Result {
        let data = try encoded(envelope)
        return try CallTool.Result(
            content: [
                .text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)
            ],
            structuredContent: try JSONDecoder().decode(Value.self, from: data),
            isError: false
        )
    }

    private static func errorResult(_ error: MCPToolError) throws -> CallTool.Result {
        let data = try encoded(error.payload)
        return try CallTool.Result(
            content: [
                .text(text: String(decoding: data, as: UTF8.self), annotations: nil, _meta: nil)
            ],
            structuredContent: try JSONDecoder().decode(Value.self, from: data),
            isError: true
        )
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(
                date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return try encoder.encode(value)
    }

    private static func convertArguments(_ values: [String: Value]) throws -> [String: MCPJSONValue]
    {
        let data = try JSONEncoder().encode(values)
        return try JSONDecoder().decode([String: MCPJSONValue].self, from: data)
    }

    private static func title(for tool: MCPTool) -> String {
        switch tool {
        case .summary: "Summarize MonMon income and expenses"
        case .dataStatus: "MonMon data status"
        case .accounts: "List MonMon accounts"
        case .transactions: "List MonMon transactions"
        case .transfers: "List MonMon transfers"
        case .categories: "List MonMon categories"
        case .recurringRules: "List MonMon recurring rules"
        case .budgetJars: "List MonMon budget jars"
        case .goals: "List MonMon goals"
        case .trips: "List MonMon trips"
        case .savings: "List MonMon savings records"
        case .investments: "List MonMon investment records"
        case .debts: "List MonMon debt records"
        case .pendingCaptures: "List MonMon pending captures"
        }
    }

    private static func description(for tool: MCPTool) -> String {
        switch tool {
        case .dataStatus:
            "Read AI permission, build flavour, local-store availability and read time. No arguments."
        case .summary:
            "Sum saved income and expenses using exact decimals, separately per currency. Required dateFrom inclusive/dateTo exclusive are ISO 8601 instants with timezone. Optional groupBy: none, category or budgetJar returns expense breakdowns. Jar filters select expenses only and follow app routing. Excludes transfers, pending captures, savings and investment movements; not account balances or jar allocation totals."
        case .accounts:
            "List cash and credit accounts with opening balance, credit limit and currency. Filter kind or creation time; these are not computed current balances."
        case .transactions:
            "List posted income and expense transactions with amount, account, category, trip and jar override. dateFrom/dateTo filter occurredAt inclusively. Use monmon_summary for totals."
        case .transfers:
            "List internal account transfers with amount, source and destination accounts. Date filters use occurredAt; transfers are not income or expenses."
        case .categories:
            "List income and expense categories with names, icons and assigned budget jar. Filter by kind, budgetJarID or creation time."
        case .recurringRules:
            "List recurring income/expense schedules with amount, frequency, account, category and pause state. Date filters use anchorDate; rules are not posted transactions."
        case .budgetJars:
            "List budget jars with allocation percentages and custom, savings or investment role. Filter role or creation time; use summary for transaction spending."
        case .goals:
            "List financial goals with target amount, earmarked amount, monthly contribution and funding jar. Date filters use targetDate."
        case .trips:
            "List trip workspaces with status, linked goal and funding jar. Date filters use startedAt."
        case .savings:
            "List savings deposits and withdrawals. Select recordType; date filters use openedAt for deposits and withdrawnAt for withdrawals."
        case .investments:
            "List fund/ETF/gold instruments, holdings and sales. Select recordType; dates use priceAsOf, purchasedAt (or createdAt), and soldAt respectively."
        case .debts:
            "List borrowed/lent debts and debt payments with linked accounts. Select recordType; date filters use openedAt for debts and occurredAt for payments."
        case .pendingCaptures:
            "List captured transaction drafts awaiting review, with amount, account and category. Date filters use occurredAt. These are not posted spending."
        }
    }
}
