import AppleDocsCore
import FastMCP
import Foundation

struct FetchExternalDocTool: MCPTool {
  let name = "fetchExternalDocumentation"
  let description: String? =
    "Fetch external Swift-DocC documentation by absolute https URL and return as markdown"

  var annotations: Tool.Annotations {
    Tool.Annotations(
      title: "Fetch External Documentation",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )
  }

  @Schemable
  struct Parameters: Sendable {
    let url: String
  }

  func call(with args: Parameters) async throws(ToolError) -> Content {
    do {
      let markdown = try await AppleDocsActions.fetchExternal(url: args.url)
      return [ToolContentItem(text: markdown)]
    } catch {
      throw ToolError(
        "Error fetching external content for \"\(args.url)\": \(error.localizedDescription)")
    }
  }
}
