import AppleDocsCore
import Foundation

struct SearchCommand: CLICommand {
  let name = "search"
  let usage = "search <query> [--json] — Search Apple Developer documentation"

  func run(arguments: [String]) async throws {
    let parsed = CLIArgParser.parse(arguments)
    let query = parsed.positional.joined(separator: " ")

    guard !query.isEmpty else {
      printToStdErr("Error: search requires a query")
      printToStdErr("Usage: \(usage)")
      Foundation.exit(1)
    }

    let output = try await AppleDocsActions.search(query: query)

    if parsed.json {
      print(output.json)
    } else {
      print(output.formatted)
    }
  }
}
