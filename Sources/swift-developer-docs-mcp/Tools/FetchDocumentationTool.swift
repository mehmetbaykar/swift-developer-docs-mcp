import AppleDocsCore
import FastMCP
import Foundation

struct FetchAppleDocsTool: MCPTool {
  let name = "fetchAppleDocumentation"
  let description: String? = "Fetch Apple Developer documentation by path and return as markdown"

  var annotations: Tool.Annotations {
    Tool.Annotations(
      title: "Fetch Apple Documentation",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )
  }

  @Schemable
  struct Parameters: Sendable {
    let path: String
  }

  func call(with args: Parameters) async throws(ToolError) -> Content {
    do {
      let markdown = try await AppleDocsActions.fetch(path: args.path)
      return [ToolContentItem(text: markdown)]
    } catch {
      throw ToolError(error.localizedDescription)
    }
  }
}
