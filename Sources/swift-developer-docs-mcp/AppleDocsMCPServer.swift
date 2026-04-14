import FastMCP
import Foundation

struct AppleDocsMCPServer: Sendable {
  let name: String
  let version: String
  let title: String
  let instructions: String

  init(
    name: String = "swift-developer-docs-mcp",
    version: String = "1.4.3",
    title: String = "Swift Apple Developer Docs MCP",
    instructions: String =
      "Search and fetch Apple Developer documentation, Human Interface Guidelines, WWDC video transcripts, and external Swift-DocC content as AI-friendly Markdown."
  ) {
    self.name = name
    self.version = version
    self.title = title
    self.instructions = instructions
  }

  func builder(transport: Transport = .stdio) -> FastMCP.Builder {
    FastMCP.builder()
      .name(name)
      .version(version)
      .title(title)
      .instructions(instructions)
      .addTools(makeTools())
      .transport(transport)
  }

  func makeServer() async -> Server {
    let server = Server(
      name: name,
      version: version,
      title: title,
      instructions: instructions,
      capabilities: Server.Capabilities(
        tools: .init(listChanged: false)
      )
    )

    await server.register(tools: makeTools())
    return server
  }

  private func makeTools() -> [any MCPTool] {
    [
      SearchAppleDocsTool(),
      FetchAppleDocsTool(),
      FetchExternalDocTool(),
      FetchVideoTranscriptTool(),
    ]
  }
}
