import AppleDocsCore
import Foundation

struct FetchCommand: CLICommand {
  let name = "fetch"
  let usage = "fetch <path> — Fetch and render Apple documentation as markdown"

  func run(arguments: [String]) async throws {
    let path = arguments.joined(separator: " ")
    guard !path.isEmpty else {
      printToStdErr("Error: fetch requires a documentation path")
      printToStdErr("Usage: \(usage)")
      Foundation.exit(1)
    }

    let markdown = try await AppleDocsActions.fetch(path: path)
    print(markdown)
  }
}
