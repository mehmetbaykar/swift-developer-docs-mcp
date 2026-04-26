import AppleDocsCore
import FastMCP
import Foundation

@Tool("Fetch external Swift-DocC documentation by absolute https URL and return as markdown")
struct FetchExternalDocumentationTool {
  @Generable
  struct Arguments {
    @Parameter("Absolute HTTPS URL for external Swift-DocC documentation")
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
}
