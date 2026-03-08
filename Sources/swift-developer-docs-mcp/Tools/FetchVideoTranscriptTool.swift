import AppleDocsCore
import FastMCP
import Foundation

struct FetchVideoTranscriptTool: MCPTool {
  let name = "fetchAppleVideoTranscript"
  let description: String? =
    "Fetch transcript for an Apple Developer video path and return as markdown"

  var annotations: Tool.Annotations {
    Tool.Annotations(
      title: "Fetch Apple Video Transcript",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )
  }

  @Schemable
  struct Parameters: Sendable {
    let path: String
  }

  func call(with args: Parameters) async throws(ToolError) -> Content {
    do {
      let markdown = try await AppleDocsActions.fetchVideo(path: args.path)
      return [ToolContentItem(text: markdown)]
    } catch {
      throw ToolError(
        "Error fetching Apple video transcript for \"\(args.path)\": \(error.localizedDescription)")
    }
  }
}
