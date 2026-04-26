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

  func builder(transport: Transport = .stdio) throws -> FastMCP.Builder {
    try FastMCP.builder()
      .name(name)
      .version(version)
      .title(title)
      .instructions(instructions)
      .addTools(makeTools())
      .transport(transport)
  }

  private func makeTools() -> [any Tool] {
    [
      SearchAppleDocumentationTool(),
      FetchAppleDocumentationTool(),
      FetchExternalDocumentationTool(),
      FetchAppleVideoTranscriptTool(),
    ]
  }
}
