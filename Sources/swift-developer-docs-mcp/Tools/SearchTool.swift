import AppleDocsCore
import FastMCP
import Foundation

struct SearchAppleDocsTool: MCPStructuredTool {
  typealias Output = StructuredSearchResponse

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

  @Schemable
  struct StructuredSearchResult: Codable, Sendable {
    let title: String
    let url: String
    let description: String
    let breadcrumbs: [String]
    let tags: [String]
    let type: String

    init(
      title: String,
      url: String,
      description: String,
      breadcrumbs: [String],
      tags: [String],
      type: String
    ) {
      self.title = title
      self.url = url
      self.description = description
      self.breadcrumbs = breadcrumbs
      self.tags = tags
      self.type = type
    }
  }

  @Schemable
  struct StructuredSearchResponse: Codable, Sendable {
    let query: String
    let results: [StructuredSearchResult]

    init(query: String, results: [StructuredSearchResult]) {
      self.query = query
      self.results = results
    }
  }

  func callStructured(with args: Parameters) async throws(ToolError)
    -> StructuredToolResult<StructuredSearchResponse>
  {
    do {
      let output = try await AppleDocsActions.search(query: args.query)
      guard let response = output.response else {
        throw ToolError("Search failed: unable to decode structured response")
      }

      let structured = StructuredSearchResponse(
        query: response.query,
        results: response.results.map {
          StructuredSearchResult(
            title: $0.title,
            url: $0.url,
            description: $0.description,
            breadcrumbs: $0.breadcrumbs,
            tags: $0.tags,
            type: $0.type
          )
        }
      )

      return StructuredToolResult(structuredContent: structured) {
        ToolContentItem(text: output.formatted)
      }
    } catch {
      throw ToolError("Search failed: \(error.localizedDescription)")
    }
  }
}
