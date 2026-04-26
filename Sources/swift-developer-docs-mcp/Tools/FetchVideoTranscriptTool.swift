import AppleDocsCore
import FastMCP
import Foundation

@Tool("Fetch transcript for an Apple Developer video path and return as markdown")
struct FetchAppleVideoTranscriptTool {
  @Generable
  struct Arguments {
    @Parameter("Apple Developer video path, for example /videos/play/wwdc2024/10133")
    var path: String
  }

  func execute(_ arguments: Arguments) async throws -> String {
    do {
      return try await AppleDocsActions.fetchVideo(path: arguments.path)
    } catch {
      throw ToolExecutionError(
        "Error fetching Apple video transcript for \"\(arguments.path)\": \(error.localizedDescription)"
      )
    }
  }
}
