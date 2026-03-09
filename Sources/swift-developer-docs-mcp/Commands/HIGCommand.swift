import AppleDocsCore
import Foundation

struct HIGCommand: CLICommand {
  let name = "hig"
  let usage = "hig [path] [--json] — Fetch Apple Human Interface Guidelines"

  func run(arguments: [String]) async throws {
    let parsed = CLIArgParser.parse(arguments)
    let client = AppleDocsClient.live

    let markdown: String
    let sourceUrl: String

    if parsed.positional.isEmpty {
      markdown = try await client.fetchHIGTableOfContents()
      sourceUrl = "https://developer.apple.com/design/human-interface-guidelines/"
    } else {
      let path = parsed.positional.joined(separator: " ")
      markdown = try await client.fetchHIG(path)
      sourceUrl = "https://developer.apple.com/design/human-interface-guidelines/\(path)"
    }

    if parsed.json {
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
