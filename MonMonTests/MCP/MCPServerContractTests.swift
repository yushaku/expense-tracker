import Foundation
import MCP
import Testing

@testable import MonMon

@Suite("MCP server contract")
struct MCPServerContractTests {
    #if os(macOS)
        @Test(
            "Embedded stdio helper handshakes, lists tools, and stops at EOF",
            .timeLimit(.minutes(1)))
        func subprocessStdio() throws {
            let helperURL = Bundle.main.bundleURL
                .appending(path: "Contents/Helpers/MonMonMCPServer")
            #expect(FileManager.default.isExecutableFile(atPath: helperURL.path))

            let process = Process()
            let input = Pipe()
            let output = Pipe()
            let error = Pipe()
            process.executableURL = helperURL
            process.standardInput = input
            process.standardOutput = output
            process.standardError = error
            try process.run()
            defer {
                if process.isRunning { process.terminate() }
            }

            try writeLine(
                [
                    "jsonrpc": "2.0", "id": 1, "method": "initialize",
                    "params": [
                        "protocolVersion": "2025-11-25",
                        "capabilities": [:],
                        "clientInfo": ["name": "MonMonTests", "version": "1"],
                    ],
                ],
                to: input.fileHandleForWriting
            )
            let initialized = try readLine(from: output.fileHandleForReading)
            #expect(initialized["id"] as? Int == 1)
            #expect(
                (initialized["result"] as? [String: Any])?["protocolVersion"] as? String
                    == "2025-11-25")

            try writeLine(
                ["jsonrpc": "2.0", "method": "notifications/initialized"],
                to: input.fileHandleForWriting
            )
            try writeLine(
                ["jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": [:]],
                to: input.fileHandleForWriting
            )
            let listed = try readLine(from: output.fileHandleForReading)
            let tools = (listed["result"] as? [String: Any])?["tools"] as? [[String: Any]]
            #expect(tools?.count == 13)

            try input.fileHandleForWriting.close()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            _ = error.fileHandleForReading.readDataToEndOfFile()
        }
    #endif

    @MainActor
    @Test("In-memory handshake exposes exactly 13 annotated read-only tools")
    func toolList() async throws {
        let provider = ContractDataProvider()
        let server = await MCPServerAdapter.makeServer(service: MCPService(provider: provider))
        let client = Client(name: "MonMonTests", version: "1")
        let transports = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: transports.server)
        _ = try await client.connect(transport: transports.client)
        defer {
            Task {
                await client.disconnect()
                await server.stop()
            }
        }

        let listed = try await client.listTools()
        #expect(listed.tools.count == 13)
        #expect(Set(listed.tools.map(\.name)) == Set(MCPTool.allCases.map(\.rawValue)))
        for tool in listed.tools {
            #expect(tool.annotations.readOnlyHint == true)
            #expect(tool.annotations.destructiveHint == false)
            #expect(tool.annotations.idempotentHint == true)
            #expect(tool.annotations.openWorldHint == false)
            #expect(tool.inputSchema.objectValue?["type"]?.stringValue == "object")
            #expect(tool.outputSchema?.objectValue?["type"]?.stringValue == "object")
        }
    }

    @MainActor
    @Test("Tool call returns matching structured content and JSON text fallback")
    func structuredResult() async throws {
        let provider = ContractDataProvider()
        let server = await MCPServerAdapter.makeServer(service: MCPService(provider: provider))
        let client = Client(name: "MonMonTests", version: "1")
        let transports = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: transports.server)
        _ = try await client.connect(transport: transports.client)

        let context: RequestContext<CallTool.Result> = try await client.callTool(
            name: MCPTool.accounts.rawValue,
            arguments: ["limit": 1]
        )
        let result = try await context.value
        let text = try #require(result.content.first?.textValue)
        let textValue = try JSONDecoder().decode(Value.self, from: Data(text.utf8))
        let fallback = try JSONDecoder().decode(
            [String: MCPJSONValue].self,
            from: Data(text.utf8)
        )

        #expect(result.isError == false)
        #expect(result.structuredContent == textValue)
        #expect(result.structuredContent?.objectValue?["schemaVersion"]?.stringValue == "1.0")
        #expect(result.structuredContent?.objectValue?["records"]?.arrayValue?.count == 1)
        #expect(fallback["page"]?.objectValue?["nextCursor"] == .null)
        #expect(fallback["sync"]?.objectValue?["source"] == .string("localSnapshot"))

        await client.disconnect()
        await server.stop()
    }

    @MainActor
    @Test("Tool errors have the normalized safe shape")
    func normalizedError() async throws {
        let provider = ContractDataProvider(error: .disabled)
        let server = await MCPServerAdapter.makeServer(service: MCPService(provider: provider))
        let client = Client(name: "MonMonTests", version: "1")
        let transports = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: transports.server)
        _ = try await client.connect(transport: transports.client)

        let context: RequestContext<CallTool.Result> = try await client.callTool(
            name: MCPTool.accounts.rawValue
        )
        let result = try await context.value
        let error = result.structuredContent?.objectValue?["error"]?.objectValue

        #expect(result.isError == true)
        #expect(error?["code"]?.stringValue == "MCP_DISABLED")
        #expect(error?["retryable"]?.boolValue == false)
        #expect(error?.keys.sorted() == ["code", "message", "retryable"])

        await client.disconnect()
        await server.stop()
    }
}

#if os(macOS)
    private enum SubprocessError: Error {
        case unexpectedEOF
        case invalidJSON
    }

    private func writeLine(_ object: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func readLine(from handle: FileHandle) throws -> [String: Any] {
        var data = Data()
        while true {
            guard let byte = try handle.read(upToCount: 1), !byte.isEmpty else {
                throw SubprocessError.unexpectedEOF
            }
            if byte[byte.startIndex] == 0x0A { break }
            data.append(byte)
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SubprocessError.invalidJSON
        }
        return object
    }
#endif

@MainActor
private final class ContractDataProvider: MCPDataProviding {
    private let error: MCPToolError?

    init(error: MCPToolError? = nil) {
        self.error = error
    }

    func status() async -> MCPSyncMetadata {
        MCPSyncMetadata(
            flavour: "dev", accessAllowed: error != .disabled,
            source: "localSnapshot", freshness: .fresh,
            lastSnapshotAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func records(for tool: MCPTool) async throws -> [MCPRecord] {
        if let error { throw error }
        let id = UUID(
            uuid: (
                0xAA, 0xAA, 0xAA, 0xAA, 0xBB, 0xBB, 0xCC, 0xCC,
                0xDD, 0xDD, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE
            ))
        return [
            MCPRecord(
                recordType: "CashAccount", id: id,
                sortDate: Date(timeIntervalSince1970: 1_700_000_000),
                fields: [
                    "recordType": .string("CashAccount"),
                    "id": .string(id.uuidString.lowercased()),
                    "createdAt": .string("2023-11-14T22:13:20.000Z"),
                ]
            )
        ]
    }
}

private extension Tool.Content {
    var textValue: String? {
        guard case .text(let text, _, _) = self else { return nil }
        return text
    }
}
