import AppleDocsCore
import Foundation

struct VideoCommand: CLICommand {
  let name = "video"
  let usage = "video <path> [--json] — Fetch WWDC video transcript"

  func run(arguments: [String]) async throws {
    let parsed = CLIArgParser.parse(arguments)

    guard !parsed.positional.isEmpty else {
      printToStdErr("Error: video requires a path")
      printToStdErr("Usage: \(usage)")
      printToStdErr("")
      printToStdErr("Examples:")
      printToStdErr("  video videos/play/wwdc2021/10133")
      Foundation.exit(1)
    }

    let path = parsed.positional.joined(separator: " ")
    let client = AppleDocsClient.live
    let markdown = try await client.fetchVideo(path)

    if parsed.json {
      let sourceUrl = "https://developer.apple.com/\(path)/"
      let jsonOutput: [String: String] = ["url": sourceUrl, "content": markdown]
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(jsonOutput)
      if let jsonString = String(data: data, encoding: .utf8) {
        print(jsonString)
      }
    } else {
      print(markdown)
    }
  }
}
