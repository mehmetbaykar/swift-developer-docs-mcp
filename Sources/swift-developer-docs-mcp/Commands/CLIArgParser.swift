import Foundation

struct CLIParseResult {
  let positional: [String]
  let json: Bool
  let unknownOptions: [String]
}

enum CLIArgParser {
  static func parse(_ args: [String]) -> CLIParseResult {
    var positional: [String] = []
    var json = false
    var unknownOptions: [String] = []

    for arg in args {
      if arg == "--json" {
        json = true
      } else if arg.hasPrefix("--") {
        unknownOptions.append(arg)
      } else if !arg.hasPrefix("--") {
        positional.append(arg)
      }
    }

    return CLIParseResult(
      positional: positional,
      json: json,
      unknownOptions: unknownOptions
    )
  }
}
