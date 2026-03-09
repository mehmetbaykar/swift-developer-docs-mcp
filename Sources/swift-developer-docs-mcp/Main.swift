import FastMCP
import Foundation

@main
struct AppleDocsServer {
  static func main() async throws {
    let router = CLIRouter()

    if try await router.route(CommandLine.arguments) {
      return
    }

    try await FastMCP.builder()
      .name("swift-developer-docs-mcp")
      .version("1.1.0")
      .addTools([
        SearchAppleDocsTool(),
        FetchAppleDocsTool(),
        FetchExternalDocTool(),
        FetchVideoTranscriptTool(),
      ])
      .addResources([DocumentationResource()])
      .transport(.stdio)
      .shutdownSignals([.sigterm, .sigint])
      .run()
  }
}
