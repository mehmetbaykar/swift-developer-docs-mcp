import AppleDocsCore
import FastMCP
import Foundation

struct SearchAppleDocsTool: MCPTool {
  let name = "searchAppleDocumentation"
  let description: String? = "Search Apple Developer documentation and return structured results"

  var annotations: Tool.Annotations {
    Tool.Annotations(
      title: "Search Apple Documentation",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )
  }

  @Schemable
  struct Parameters: Sendable {
    let query: String
  }

  func call(with args: Parameters) async throws(ToolError) -> Content {
    do {
      let output = try await AppleDocsActions.search(query: args.query)
      return [
        ToolContentItem(text: output.formatted),
        ToolContentItem(text: output.json),
      ]
    } catch {
      throw ToolError("Search failed: \(error.localizedDescription)")
    }
  }
}
