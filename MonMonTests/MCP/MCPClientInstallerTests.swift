#if os(macOS)
    import Foundation
    import Testing

    @testable import MonMon

    @Suite("MCP client installer")
    @MainActor
    struct MCPClientInstallerTests {
        @Test("Codex detects absent, current, conflict, repair, install, and remove")
        func codexLifecycle() async throws {
            let runner = FixtureCommandRunner()
            let helper = URL(
                fileURLWithPath: "/Applications/MonMon Dev.app/Contents/Helpers/MonMonMCPServer")
            let installer = MCPClientInstaller(
                serverName: "monmon-dev", helperURL: helper,
                runner: runner,
                claudeConfigURL: temporaryDirectory().appending(path: "claude.json"),
                isClaudeInstalled: { false }
            )

            runner.results = [.init(exitCode: 1, stdout: Data(), stderr: Data())]
            #expect(await installer.codexState() == .notConfigured)

            runner.results = [
                .init(exitCode: 0, stdout: codexJSON(command: helper.path), stderr: Data())
            ]
            #expect(await installer.codexState() == .current)

            runner.results = [
                .init(exitCode: 0, stdout: codexJSON(command: "/tmp/other"), stderr: Data())
            ]
            #expect(await installer.codexState() == .conflict)

            runner.results = [
                .init(
                    exitCode: 0,
                    stdout: codexJSON(command: "/Old/MonMon.app/Contents/Helpers/MonMonMCPServer"),
                    stderr: Data()
                )
            ]
            #expect(await installer.codexState() == .repairNeeded)

            runner.results = [
                .init(exitCode: 1, stdout: Data(), stderr: Data()),
                .init(exitCode: 0, stdout: Data(), stderr: Data()),
            ]
            try await installer.installCodex(replaceExisting: false)
            #expect(
                runner.calls.suffix(1).first?.arguments == [
                    "codex", "mcp", "add", "monmon-dev", "--", helper.path,
                ])

            runner.results = [.init(exitCode: 0, stdout: Data(), stderr: Data())]
            try await installer.removeCodex()
            #expect(runner.calls.last?.arguments == ["codex", "mcp", "remove", "monmon-dev"])
        }

        @Test("Codex refuses to replace a conflicting command without confirmation")
        func codexConflictConfirmation() async {
            let runner = FixtureCommandRunner()
            runner.results = [
                .init(exitCode: 0, stdout: codexJSON(command: "/tmp/other"), stderr: Data())
            ]
            let installer = MCPClientInstaller(
                serverName: "monmon", helperURL: URL(fileURLWithPath: "/tmp/helper"),
                runner: runner,
                claudeConfigURL: temporaryDirectory().appending(path: "claude.json"),
                isClaudeInstalled: { false }
            )

            await #expect(throws: MCPInstallerError.conflict) {
                try await installer.installCodex(replaceExisting: false)
            }
            #expect(runner.calls.count == 1)
        }

        @Test("Codex rejects a non-stdio transport even when it contains command fields")
        func codexTransportValidation() async {
            let runner = FixtureCommandRunner()
            runner.results = [
                .init(
                    exitCode: 0,
                    stdout: codexJSON(command: "/tmp/helper", transport: "http"),
                    stderr: Data()
                )
            ]
            let installer = MCPClientInstaller(
                serverName: "monmon", helperURL: URL(fileURLWithPath: "/tmp/helper"),
                runner: runner,
                claudeConfigURL: temporaryDirectory().appending(path: "claude.json"),
                isClaudeInstalled: { false }
            )

            #expect(await installer.codexState() == .conflict)
        }

        @Test("Claude update preserves unrelated keys and removes only MonMon")
        func claudePreservesConfiguration() async throws {
            let directory = temporaryDirectory()
            let configURL = directory.appending(path: "claude_desktop_config.json")
            let original: [String: Any] = [
                "theme": "dark",
                "mcpServers": ["other": ["command": "node", "args": ["server.js"]]],
            ]
            try JSONSerialization.data(withJSONObject: original).write(to: configURL)
            let helper = URL(
                fileURLWithPath: "/Applications/MonMon.app/Contents/Helpers/MonMonMCPServer")
            let installer = MCPClientInstaller(
                serverName: "monmon", helperURL: helper,
                runner: FixtureCommandRunner(), claudeConfigURL: configURL,
                isClaudeInstalled: { true }
            )

            #expect(try installer.claudeState() == .notConfigured)
            try installer.installClaude(replaceExisting: false)
            #expect(try installer.claudeState() == .current)
            let installed = try json(configURL)
            #expect(installed["theme"] as? String == "dark")
            #expect((installed["mcpServers"] as? [String: Any])?["other"] != nil)

            try installer.removeClaude()
            let removed = try json(configURL)
            #expect(removed["theme"] as? String == "dark")
            #expect((removed["mcpServers"] as? [String: Any])?["other"] != nil)
            #expect((removed["mcpServers"] as? [String: Any])?["monmon"] == nil)
        }

        @Test("Claude detects conflict, moved helper, and malformed JSON")
        func claudeValidation() throws {
            let directory = temporaryDirectory()
            let configURL = directory.appending(path: "claude.json")
            let helper = URL(
                fileURLWithPath: "/Applications/MonMon.app/Contents/Helpers/MonMonMCPServer")
            let installer = MCPClientInstaller(
                serverName: "monmon", helperURL: helper,
                runner: FixtureCommandRunner(), claudeConfigURL: configURL,
                isClaudeInstalled: { true }
            )

            try writeClaude(command: "/tmp/other", to: configURL)
            #expect(try installer.claudeState() == .conflict)
            #expect(throws: MCPInstallerError.conflict) {
                try installer.installClaude(replaceExisting: false)
            }

            try writeClaude(
                command: "/Old/MonMon.app/Contents/Helpers/MonMonMCPServer", to: configURL
            )
            #expect(try installer.claudeState() == .repairNeeded)

            try Data("{".utf8).write(to: configURL)
            #expect(throws: MCPInstallerError.malformedConfiguration) {
                try installer.claudeState()
            }

            let invalidArguments: [String: Any] = [
                "mcpServers": ["monmon": ["command": helper.path, "args": "--unsafe"]]
            ]
            try JSONSerialization.data(withJSONObject: invalidArguments).write(to: configURL)
            #expect(try installer.claudeState() == .conflict)

            let invalidEntry: [String: Any] = ["mcpServers": ["monmon": "not-an-object"]]
            try JSONSerialization.data(withJSONObject: invalidEntry).write(to: configURL)
            #expect(try installer.claudeState() == .conflict)

            let invalidServers: [String: Any] = ["mcpServers": ["not-an-object"]]
            try JSONSerialization.data(withJSONObject: invalidServers).write(to: configURL)
            #expect(throws: MCPInstallerError.malformedConfiguration) {
                try installer.claudeState()
            }
        }

        @Test("Hermes uses scoped JSON config commands and validates the saved entry")
        func hermesLifecycle() async throws {
            let runner = FixtureCommandRunner()
            let helper = URL(
                fileURLWithPath: "/Applications/MonMon Dev.app/Contents/Helpers/MonMonMCPServer")
            let installer = MCPClientInstaller(
                serverName: "monmon-dev", helperURL: helper,
                runner: runner, hermesCommand: "/test/hermes")
            let missing = MCPProcessResult(
                exitCode: 1,
                stdout: Data("Config key not set: mcp_servers.monmon-dev".utf8), stderr: Data())
            let current = MCPProcessResult(
                exitCode: 0,
                stdout: try JSONSerialization.data(withJSONObject: [
                    "command": helper.path, "args": [],
                ]),
                stderr: Data())
            let success = MCPProcessResult(exitCode: 0, stdout: Data(), stderr: Data())
            runner.results = [missing, success, current]
            try await installer.installHermes(replaceExisting: false)
            #expect(
                runner.calls[0].arguments == [
                    "/test/hermes", "config", "get", "mcp_servers.monmon-dev", "--json",
                ])
            let set = runner.calls[1].arguments
            #expect(
                Array(set.prefix(4)) == ["/test/hermes", "config", "set", "mcp_servers.monmon-dev"])
            let entry = try #require(
                JSONSerialization.jsonObject(with: Data(set[4].utf8)) as? [String: Any])
            #expect(entry["command"] as? String == helper.path)
            runner.results = [current, success, missing]
            try await installer.removeHermes()
            #expect(
                runner.calls[4].arguments == [
                    "/test/hermes", "config", "unset", "mcp_servers.monmon-dev",
                ])
        }

        @Test("Hermes fails closed on malformed config, CLI errors and conflicting entries")
        func hermesValidation() async throws {
            let runner = FixtureCommandRunner()
            let installer = MCPClientInstaller(
                serverName: "monmon", helperURL: URL(fileURLWithPath: "/tmp/helper"), runner: runner
            )
            for value in [
                "{", "null", "{\"command\":\"/tmp/other\"}",
                "{\"command\":\"/tmp/helper\",\"enabled\":false}",
                "{\"command\":\"/tmp/helper\",\"args\":\"bad\"}",
            ] {
                runner.results = [.init(exitCode: 0, stdout: Data(value.utf8), stderr: Data())]
                await #expect(throws: MCPInstallerError.conflict) {
                    try await installer.installHermes(replaceExisting: false)
                }
            }
            runner.results = [.init(exitCode: 2, stdout: Data(), stderr: Data("Invalid YAML".utf8))]
            #expect(await installer.hermesState() == .conflict)
            runner.results = [.init(exitCode: 127, stdout: Data(), stderr: Data())]
            #expect(await installer.hermesState() == .unavailable)
            runner.results = [
                .init(
                    exitCode: 0,
                    stdout: Data(
                        "{\"command\":\"/Old/MonMon.app/Contents/Helpers/MonMonMCPServer\"}".utf8),
                    stderr: Data())
            ]
            #expect(await installer.hermesState() == .repairNeeded)
        }

        private func temporaryDirectory() -> URL {
            let url = FileManager.default.temporaryDirectory
                .appending(
                    path: "MCPClientInstallerTests-\(UUID().uuidString)",
                    directoryHint: .isDirectory)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                preconditionFailure("Could not create test directory: \(error)")
            }
            return url
        }

        private func codexJSON(command: String, transport: String = "stdio") -> Data {
            do {
                return try JSONSerialization.data(withJSONObject: [
                    "name": "monmon",
                    "transport": ["type": transport, "command": command, "args": []],
                ])
            } catch {
                preconditionFailure("Could not encode test fixture: \(error)")
            }
        }

        private func writeClaude(command: String, to url: URL) throws {
            let object: [String: Any] = [
                "mcpServers": ["monmon": ["command": command, "args": []]]
            ]
            try JSONSerialization.data(withJSONObject: object).write(to: url)
        }

        private func json(_ url: URL) throws -> [String: Any] {
            try #require(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        }
    }

    @MainActor
    private final class FixtureCommandRunner: MCPCommandRunning {
        struct Call: Equatable {
            let arguments: [String]
        }

        var results: [MCPProcessResult] = []
        private(set) var calls: [Call] = []

        func run(arguments: [String]) async throws -> MCPProcessResult {
            calls.append(Call(arguments: arguments))
            guard !results.isEmpty else { throw MCPInstallerError.commandFailed }
            return results.removeFirst()
        }
    }
#endif
