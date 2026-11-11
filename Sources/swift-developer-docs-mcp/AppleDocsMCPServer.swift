import FastMCP
import Foundation

struct AppleDocsMCPServer: Sendable {
  let name: String
  let version: String
  let title: String
  let instructions: String

  init(
    name: String = "swift-developer-docs-mcp",
    version: String = "1.8.0",
    title: String = "Swift Apple Developer Docs MCP",
    instructions: String =
      "Search and fetch Apple Developer documentation, Human Interface Guidelines, WWDC video transcripts, and external Swift-DocC content as AI-friendly Markdown. The conformance conditions in Apple's data, such as \"Conforms when `Element` conforms to `Hashable`.\", can be missing or wrong. When a condition matters, read the declaration in the module's `.swiftinterface` file in the SDK."
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

  func toolInputSchemas() throws -> [String: String] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var schemas: [String: String] = [:]
    for tool in makeTools() {
      let data = try encoder.encode(tool.parameters)
      schemas[tool.name] = String(decoding: data, as: UTF8.self)
    }
    return schemas
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
