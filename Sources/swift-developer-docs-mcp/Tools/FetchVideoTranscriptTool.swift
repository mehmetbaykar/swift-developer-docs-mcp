import AppleDocsCore
import FastMCP
import Foundation

@Tool(
  "Fetch the transcript of an Apple Developer video (https://developer.apple.com/videos) by path and return it as Markdown"
)
struct FetchAppleVideoTranscriptTool {
  @Generable
  struct Arguments {
    @Parameter(
      "Apple video path (e.g., '/videos/play/wwdc2021/10133' or '/videos/play/meet-with-apple/208')"
    )
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

  func makeOutputSegments(from arguments: GeneratedContent) async throws -> [Transcript.Segment] {
    let markdown = try await execute(try Arguments(arguments))
    return [.text(.init(content: markdown))]
  }
}
