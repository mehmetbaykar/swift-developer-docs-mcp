import AppleDocsCore
import FastMCP
import Foundation

@Tool(
  "Fetch a page of Apple Developer documentation (https://developer.apple.com/documentation) or the Human Interface Guidelines (https://developer.apple.com/design/human-interface-guidelines) by path and return it as Markdown"
)
struct FetchAppleDocumentationTool {
  @Generable
  struct Arguments {
    @Parameter(
      "Documentation path (e.g., '/documentation/swift', '/documentation/swiftui/view', '/design/human-interface-guidelines/foundations/color')"
    )
    var path: String
  }

  func execute(_ arguments: Arguments) async throws -> String {
    try await Self.contentBlocks(for: arguments.path).joined(separator: "\n\n")
  }

  func makeOutputSegments(from arguments: GeneratedContent) async throws -> [Transcript.Segment] {
    let parsed = try Arguments(arguments)
    return try await Self.contentBlocks(for: parsed.path).map { block in
      .text(.init(content: block))
    }
  }

  static func contentBlocks(for path: String) async throws -> [String] {
    do {
      let endpoint = try AppleDocsClient.resolveFetchEndpoint(path)
      if endpoint.hasPrefix("/documentation/") {
        let docPath = String(endpoint.dropFirst("/documentation/".count))
        let document = try await AppleDocsActions.fetchDocument(path: docPath)
        return referenceDocumentationBlocks(
          markdown: document.markdown,
          requestedPath: document.requestedPath,
          resolvedPath: document.path
        )
      }

      let markdown = try await AppleDocsClient.live.unifiedFetch(input: path)
      return [markdown]
    } catch {
      throw ToolExecutionError(error.localizedDescription)
    }
  }

  static func referenceDocumentationBlocks(
    markdown: String,
    requestedPath: String,
    resolvedPath: String
  ) -> [String] {
    guard resolvedPath.lowercased() != requestedPath.lowercased() else {
      return [markdown]
    }
    let notice =
      "No page exists at /documentation/\(requestedPath). This is the page at /documentation/\(resolvedPath)."
    return [notice, markdown]
  }
}
