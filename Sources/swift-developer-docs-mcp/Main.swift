import FastMCP
import Foundation

@main
struct AppleDocsServer {
  static func main() async throws {
    let mcpServer = AppleDocsMCPServer()
    let router = CLIRouter(version: mcpServer.version)

    if try await router.route(CommandLine.arguments) {
      return
    }

    try await mcpServer.builder(transport: .stdio)
      .shutdownSignals([.sigterm, .sigint])
      .run()
  }
}
