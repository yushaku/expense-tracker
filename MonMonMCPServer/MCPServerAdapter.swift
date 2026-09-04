import Foundation
import MCP

#if MCP_ADAPTER_TEST
    @testable import MonMon
#endif

enum MCPServerAdapter {
    static let serverVersion = "1.0.0"

    static var tools: [Tool] {
        MCPTool.allCases.map(toolDefinition)
    }

    @MainActor
    static func makeServer(service: MCPService) async -> Server {
        let server = Server(
            name: "monmon",
            version: serverVersion,
            title: "MonMon read-only data",
            instructions:
                "Provides raw MonMon records only. Calculate and interpret them in the client.",
            capabilities: .init(tools: .init(listChanged: false)),
            configuration: .strict
        )
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: tools)
        }
        await server.withMethodHandler(CallTool.self) { params in
            guard let tool = MCPTool(rawValue: params.name) else {
                return try errorResult(.invalidArgument)
            }
            do {
                let arguments = try convertArguments(params.arguments ?? [:])
                let envelope = try await service.call(tool: tool, arguments: arguments)
                return try successResult(envelope)
            } catch let error as MCPToolError {
                return try errorResult(error)
            } catch {
                return try errorResult(.storeUnavailable)
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

    private static func successResult(_ envelope: MCPResponseEnvelope) throws -> CallTool.Result {
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
        if tool == .dataStatus {
            return
                "Reports access permission, build flavour, and local snapshot freshness."
        }
        return
            "Returns paginated raw stored records without totals, projections, or financial advice."
    }
}
