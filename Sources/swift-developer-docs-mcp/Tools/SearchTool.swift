import AppleDocsCore
import FastMCP
import Foundation

@Tool("Search Apple Developer documentation and return structured results")
struct SearchAppleDocumentationTool {
  @Generable
  struct Arguments {
    @Parameter("Search query")
    var query: String
  }

  @Generable
  struct StructuredSearchResult: Codable, Sendable {
    let title: String
    let url: String
    let description: String
    let breadcrumbs: [String]
    let tags: [String]
    let type: String
  }

  @Generable
  struct StructuredSearchResponse: Codable, Sendable {
    let query: String
    let results: [StructuredSearchResult]
  }

  func execute(_ arguments: Arguments) async throws -> StructuredSearchResponse {
    do {
      let output = try await AppleDocsActions.search(query: arguments.query)
      guard let response = output.response else {
        throw ToolExecutionError("Search failed: unable to decode structured response")
      }

      return StructuredSearchResponse(
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
    } catch {
      throw ToolExecutionError("Search failed: \(error.localizedDescription)")
    }
  }
}
