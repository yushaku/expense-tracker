import Foundation
import MCP

@main
enum MonMonMCPServerMain {
    @MainActor
    static func main() async {
        do {
            let bundle = try containingAppBundle()
            let configuration = try MCPRuntimeConfiguration.current(bundle: bundle)
            guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier) else {
                throw MCPToolError.storeUnavailable
            }

            let consent = MCPConsentStore(defaults: defaults)
            let snapshot = MCPDiskSnapshotReader(configuration: configuration)
            let provider = MCPSnapshotDataProvider(
                configuration: configuration,
                consent: consent,
                snapshot: snapshot
            )
            let server = await MCPServerAdapter.makeServer(
                service: MCPService(provider: provider)
            )
            try await server.start(transport: StdioTransport())
            await server.waitUntilCompleted()
        } catch let error as MCPToolError {
            report(error.rawValue)
        } catch {
            report(MCPToolError.storeUnavailable.rawValue)
        }
    }

    private static func containingAppBundle() throws -> Bundle {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let appURL =
            executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard appURL.pathExtension == "app", let bundle = Bundle(url: appURL) else {
            throw MCPToolError.storeUnavailable
        }
        return bundle
    }

    private static func report(_ code: String) {
        FileHandle.standardError.write(Data("\(code)\n".utf8))
    }
}
