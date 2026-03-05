import AppleDocsCore
import Foundation

struct SearchCommand: CLICommand {
  let name = "search"
  let usage = "search <query> — Search Apple Developer documentation"

  func run(arguments: [String]) async throws {
    let query = arguments.joined(separator: " ")
    guard !query.isEmpty else {
      printToStdErr("Error: search requires a query")
      printToStdErr("Usage: \(usage)")
      Foundation.exit(1)
    }

    let output = try await AppleDocsActions.search(query: query)
    print(output.formatted)
    print(output.json)
  }
}
