import Foundation

struct CLIParseResult {
  let positional: [String]
  let json: Bool
}

enum CLIArgParser {
  static func parse(_ args: [String]) -> CLIParseResult {
    var positional: [String] = []
    var json = false

    for arg in args {
      if arg == "--json" {
        json = true
      } else if !arg.hasPrefix("--") {
        positional.append(arg)
      }
    }

    return CLIParseResult(positional: positional, json: json)
  }
}
