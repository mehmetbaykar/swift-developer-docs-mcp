import FastMCP
import Foundation

@main
struct AppleDocsServer {
  static func main() async throws {
    let router = CLIRouter()
    let mcpServer = AppleDocsMCPServer()

    if try await router.route(CommandLine.arguments) {
      return
    }

    try await mcpServer.builder(transport: .stdio)
      .shutdownSignals([.sigterm, .sigint])
      .run()
  }
}
