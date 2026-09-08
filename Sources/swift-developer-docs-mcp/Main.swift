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
      // The stdio transport finishes when the MCP client closes stdin, which FastMCP's
      // service group reports as an unexpected finish. That is the normal shutdown path
      // for a stdio server, so exit quietly.
      return
    } catch {
      // An error escaping `main` is a Swift fatal error (SIGILL plus a backtrace), so report
      // it like any other CLI failure instead.
      printToStdErr("swift-developer-docs-mcp: \(error.localizedDescription)")
      Foundation.exit(1)
    }
  }
}
