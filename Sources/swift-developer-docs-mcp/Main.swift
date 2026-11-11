import FastMCP
import Foundation

@main
struct AppleDocsServer {
  static func main() async throws {
    let mcpServer = AppleDocsMCPServer()
    let router = CLIRouter(version: mcpServer.version)

    do {
      if try await router.route(CommandLine.arguments) {
        return
      }
    } catch {
      printToStdErr("swift-developer-docs-mcp: \(error.localizedDescription)")
      Foundation.exit(1)
    }

    try await mcpServer.builder(transport: .stdio)
      .shutdownSignals([.sigterm, .sigint])
      .run()
  }
}
