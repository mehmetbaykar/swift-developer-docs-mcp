import AppleDocsCore
import FastMCP
import Foundation

@Tool(
  "Fetch Apple Developer documentation and Human Interface Guidelines by path and return as markdown"
)
struct FetchAppleDocumentationTool {
  @Generable
  struct Arguments {
    @Parameter(
      "Documentation, Human Interface Guidelines, video, or supported external documentation path")
    var path: String
  }

  func execute(_ arguments: Arguments) async throws -> String {
    do {
      let client = AppleDocsClient.live
      return try await client.unifiedFetch(input: arguments.path)
    } catch {
      throw ToolExecutionError(error.localizedDescription)
    }
  }
}
