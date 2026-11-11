import AppleDocsCore
import FastMCP
import Foundation

@Tool(
  "Fetch a page from a public Swift-DocC documentation site (https://www.swift.org/documentation/docc/) by absolute HTTPS URL and return it as Markdown"
)
struct FetchExternalDocumentationTool {
  @Generable
  struct Arguments {
    @Parameter(
      "External Swift-DocC URL (e.g., 'https://swiftlang.github.io/swift-docc-plugin/documentation/swiftdoccplugin')"
    )
    var url: String
  }

  func execute(_ arguments: Arguments) async throws -> String {
    do {
      return try await AppleDocsActions.fetchExternal(url: arguments.url)
    } catch {
      throw ToolExecutionError(
        "Error fetching external content for \"\(arguments.url)\": \(error.localizedDescription)")
    }
  }

  func makeOutputSegments(from arguments: GeneratedContent) async throws -> [Transcript.Segment] {
    let markdown = try await execute(try Arguments(arguments))
    return [.text(.init(content: markdown))]
  }
}
