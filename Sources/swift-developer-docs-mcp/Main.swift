import FastMCP
import Foundation
import ServiceLifecycle

@main
struct AppleDocsServer {
  static func main() async {
    let mcpServer = AppleDocsMCPServer()
    let router = CLIRouter(version: mcpServer.version)

    do {
      if try await router.route(CommandLine.arguments) {
        return
      }

      try await mcpServer.builder(transport: .stdio)
        .shutdownSignals([.sigterm, .sigint])
        .run()
    } catch let error as ServiceGroupError
      where error.errorCode == .serviceFinishedUnexpectedly
    {
      // FastMCP reports the client closing stdin this way; it is the normal stdio shutdown.
      return
    } catch {
      printToStdErr("swift-developer-docs-mcp: \(error.localizedDescription)")
      Foundation.exit(1)
    }
  }
}
