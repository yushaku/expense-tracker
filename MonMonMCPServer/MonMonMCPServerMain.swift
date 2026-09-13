import Darwin
import Foundation

/// Preserve existing client commands while using the app's exact model schema.
/// exec keeps stdin/stdout and signal handling attached to the MCP client.
@main
enum MonMonMCPServerMain {
    static func main() {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let app = executable.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard app.pathExtension == "app", let target = Bundle(url: app)?.executableURL else {
            exit(1)
        }
        let strings: [String] = [target.path, "--mcp-stdio"]
        let arguments = strings.map { string in string.withCString { strdup($0) } }
        defer { arguments.forEach { free($0) } }
        var pointers = arguments + [nil]
        pointers.withUnsafeMutableBufferPointer { buffer in
            _ = execv(target.path, buffer.baseAddress!)
        }
        FileHandle.standardError.write(Data("STORE_UNAVAILABLE\n".utf8))
        exit(1)
    }
}
