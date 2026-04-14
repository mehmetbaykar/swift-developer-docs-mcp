import AppleDocsCore
import Foundation

struct ExternalCommand: CLICommand {
  let name = "external"
  let usage = "external <url> [--json] — Fetch external Swift-DocC documentation"

  func run(arguments: [String]) async throws {
    let parsed = CLIArgParser.parse(arguments)

    if let option = parsed.unknownOptions.first {
      printToStdErr("Error: unknown option \(option)")
      printToStdErr("Usage: \(usage)")
      Foundation.exit(1)
    }

    guard !parsed.positional.isEmpty else {
      printToStdErr("Error: external requires a URL")
      printToStdErr("Usage: \(usage)")
      printToStdErr("")
      printToStdErr("Examples:")
      printToStdErr(
        "  external https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      Foundation.exit(1)
    }

    let url = parsed.positional.joined(separator: " ")
    let client = AppleDocsClient.live
    let markdown = try await client.fetchExternal(url)

    if parsed.json {
      let jsonOutput: [String: String] = ["url": url, "content": markdown]
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
