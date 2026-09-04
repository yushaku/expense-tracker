#if os(macOS)
    import Foundation

    enum MCPClientState: Equatable, Sendable {
        case unavailable
        case notConfigured
        case current
        case repairNeeded
        case conflict
    }

    enum MCPInstallerError: Error, Equatable {
        case commandFailed
        case conflict
        case malformedConfiguration
        case fileOperationFailed
    }

    struct MCPProcessResult: Equatable, Sendable {
        let exitCode: Int32
        let stdout: Data
        let stderr: Data
    }

    @MainActor
    protocol MCPCommandRunning: AnyObject {
        func run(arguments: [String]) async throws -> MCPProcessResult
    }

    @MainActor
    final class MCPProcessRunner: MCPCommandRunning {
        func run(arguments: [String]) async throws -> MCPProcessResult {
            let process = Process()
            let output = Pipe()
            let error = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = error
            return try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(
                        returning: MCPProcessResult(
                            exitCode: process.terminationStatus,
                            stdout: output.fileHandleForReading.readDataToEndOfFile(),
                            stderr: error.fileHandleForReading.readDataToEndOfFile()
                        ))
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: MCPInstallerError.commandFailed)
                }
            }
        }
    }

    @MainActor
    protocol MCPClientInstalling: AnyObject {
        func codexState() async -> MCPClientState
        func claudeState() throws -> MCPClientState
        func installCodex(replaceExisting: Bool) async throws
        func installClaude(replaceExisting: Bool) throws
        func removeCodex() async throws
        func removeClaude() throws
    }

    @MainActor
    final class MCPClientInstaller: MCPClientInstalling {
        private struct CodexConfiguration: Decodable {
            struct Transport: Decodable {
                let type: String
                let command: String
                let args: [String]
            }
            let transport: Transport
        }

        private let serverName: String
        private let helperURL: URL
        private let runner: any MCPCommandRunning
        private let claudeConfigURL: URL
        private let isClaudeInstalled: () -> Bool

        init(
            serverName: String,
            helperURL: URL,
            runner: any MCPCommandRunning = MCPProcessRunner(),
            claudeConfigURL: URL = FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/Claude/claude_desktop_config.json"),
            isClaudeInstalled: @escaping () -> Bool = {
                FileManager.default.fileExists(atPath: "/Applications/Claude.app")
            }
        ) {
            self.serverName = serverName
            self.helperURL = helperURL.standardizedFileURL
            self.runner = runner
            self.claudeConfigURL = claudeConfigURL
            self.isClaudeInstalled = isClaudeInstalled
        }

        func codexState() async -> MCPClientState {
            let result: MCPProcessResult
            do {
                result = try await runner.run(arguments: [
                    "codex", "mcp", "get", serverName, "--json",
                ])
            } catch {
                return .unavailable
            }
            guard result.exitCode == 0 else {
                return result.exitCode == 127 ? .unavailable : .notConfigured
            }
            guard
                let configuration = try? JSONDecoder().decode(
                    CodexConfiguration.self, from: result.stdout
                ),
                configuration.transport.type == "stdio"
            else {
                return .conflict
            }
            return state(
                command: configuration.transport.command, args: configuration.transport.args)
        }

        func claudeState() throws -> MCPClientState {
            guard isClaudeInstalled() else { return .unavailable }
            let root = try readClaudeConfiguration()
            guard let rawServers = root["mcpServers"] else { return .notConfigured }
            guard let servers = rawServers as? [String: Any] else {
                throw MCPInstallerError.malformedConfiguration
            }
            guard let rawEntry = servers[serverName] else { return .notConfigured }
            guard let entry = rawEntry as? [String: Any] else { return .conflict }
            guard let command = entry["command"] as? String else { return .conflict }
            let args: [String]
            if let rawArguments = entry["args"] {
                guard let configuredArguments = rawArguments as? [String] else { return .conflict }
                args = configuredArguments
            } else {
                args = []
            }
            return state(command: command, args: args)
        }

        func installCodex(replaceExisting: Bool) async throws {
            let current = await codexState()
            switch current {
            case .current:
                return
            case .conflict, .repairNeeded:
                guard replaceExisting else { throw MCPInstallerError.conflict }
                try await removeCodex()
            case .unavailable:
                throw MCPInstallerError.commandFailed
            case .notConfigured:
                break
            }
            let result = try await runner.run(arguments: [
                "codex", "mcp", "add", serverName, "--", helperURL.path,
            ])
            guard result.exitCode == 0 else { throw MCPInstallerError.commandFailed }
        }

        func installClaude(replaceExisting: Bool) throws {
            let current = try claudeState()
            switch current {
            case .current:
                return
            case .conflict, .repairNeeded:
                guard replaceExisting else { throw MCPInstallerError.conflict }
            case .unavailable:
                throw MCPInstallerError.commandFailed
            case .notConfigured:
                break
            }
            var root = try readClaudeConfiguration()
            var servers = root["mcpServers"] as? [String: Any] ?? [:]
            servers[serverName] = ["command": helperURL.path, "args": []]
            root["mcpServers"] = servers
            try writeClaudeConfiguration(root)
        }

        func removeCodex() async throws {
            let result = try await runner.run(arguments: ["codex", "mcp", "remove", serverName])
            guard result.exitCode == 0 else { throw MCPInstallerError.commandFailed }
        }

        func removeClaude() throws {
            guard FileManager.default.fileExists(atPath: claudeConfigURL.path) else { return }
            var root = try readClaudeConfiguration()
            guard var servers = root["mcpServers"] as? [String: Any] else { return }
            servers.removeValue(forKey: serverName)
            root["mcpServers"] = servers
            try writeClaudeConfiguration(root)
        }

        private func state(command: String, args: [String]) -> MCPClientState {
            guard args.isEmpty else { return .conflict }
            let commandURL = URL(fileURLWithPath: command).standardizedFileURL
            if commandURL == helperURL { return .current }
            if command.hasSuffix("/Contents/Helpers/MonMonMCPServer") { return .repairNeeded }
            return .conflict
        }

        private func readClaudeConfiguration() throws -> [String: Any] {
            guard FileManager.default.fileExists(atPath: claudeConfigURL.path) else { return [:] }
            do {
                let value = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: claudeConfigURL))
                guard let root = value as? [String: Any] else {
                    throw MCPInstallerError.malformedConfiguration
                }
                return root
            } catch let error as MCPInstallerError {
                throw error
            } catch {
                throw MCPInstallerError.malformedConfiguration
            }
        }

        private func writeClaudeConfiguration(_ root: [String: Any]) throws {
            do {
                let parent = claudeConfigURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: parent, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(
                    withJSONObject: root,
                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                )
                try data.write(to: claudeConfigURL, options: [.atomic])
            } catch {
                throw MCPInstallerError.fileOperationFailed
            }
        }
    }
#endif
