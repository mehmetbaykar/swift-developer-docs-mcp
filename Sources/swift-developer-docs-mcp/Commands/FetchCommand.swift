import AppleDocsCore
import Foundation

struct FetchCommand: CLICommand {
  let name = "fetch"
  let usage =
    "fetch <url-or-path> [--json] — Fetch Apple docs, HIG, video transcripts, or external docs"

  func run(arguments: [String]) async throws {
    let parsed = CLIArgParser.parse(arguments)

    guard !parsed.positional.isEmpty else {
      printToStdErr("Error: fetch requires a URL or documentation path")
      printToStdErr("Usage: \(usage)")
      printToStdErr("")
      printToStdErr("Examples:")
      printToStdErr("  fetch swift/array")
      printToStdErr("  fetch design/human-interface-guidelines/foundations/color")
      printToStdErr("  fetch videos/play/wwdc2021/10133")
      printToStdErr(
        "  fetch https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      Foundation.exit(1)
    }

    let input = parsed.positional.joined(separator: " ")
    let client = AppleDocsClient.live
    let markdown = try await client.unifiedFetch(input: input)

    if parsed.json {
      let endpoint = try AppleDocsClient.resolveFetchEndpoint(input)
      let sourceUrl = resolveSourceUrl(endpoint: endpoint, input: input)
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

  private func resolveSourceUrl(endpoint: String, input: String) -> String {
    if endpoint.hasPrefix("/documentation/") {
      let docPath = String(endpoint.dropFirst("/documentation/".count))
      return URLUtilities.generateAppleDocURL(docPath)
    }
    if endpoint.hasPrefix("/design/human-interface-guidelines") {
      let higPath = String(endpoint.dropFirst("/design/human-interface-guidelines".count))
      let suffix = higPath.hasPrefix("/") ? String(higPath.dropFirst()) : higPath
      if suffix.isEmpty {
        return "https://developer.apple.com/design/human-interface-guidelines/"
      }
      return "https://developer.apple.com/design/human-interface-guidelines/\(suffix)"
    }
    if endpoint.hasPrefix("/videos/play/") {
      return "https://developer.apple.com\(endpoint)/"
    }
    if endpoint.hasPrefix("/external/") {
      return String(endpoint.dropFirst("/external/".count))
    }
    return input
  }
}
