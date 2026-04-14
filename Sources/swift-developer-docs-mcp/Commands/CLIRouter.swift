import Foundation

struct CLIRouter {
  let commands: [CLICommand]
  let version: String

  init(
    version: String,
    commands: [CLICommand] = [
      SearchCommand(), FetchCommand(), HIGCommand(), VideoCommand(), ExternalCommand(),
      ServeCommand(),
    ]
  ) {
    self.version = version
    self.commands = commands
  }

  /// Returns `true` if a CLI command was matched and executed.
  func route(_ args: [String]) async throws -> Bool {
    // args[0] is the executable name
    guard args.count >= 2 else { return false }

    let subcommand = args[1]

    if subcommand == "help" || subcommand == "--help" || subcommand == "-h" {
      printUsage()
      return true
    }

    if subcommand == "version" || subcommand == "--version" || subcommand == "-v" {
      print(version)
      return true
    }

    guard let command = commands.first(where: { $0.name == subcommand }) else {
      return false
    }

    let commandArgs = Array(args.dropFirst(2))
    try await command.run(arguments: commandArgs)
    return true
  }

  private func printUsage() {
    print("Usage: swift-developer-docs-mcp <command> [arguments]")
    print()
    print("Commands:")
    for command in commands {
      print("  \(command.usage)")
    }
    print("  version, --version, -v — Print the current version")
    print()
    print("Run with no arguments to start the MCP server.")
  }
}

func printToStdErr(_ message: String) {
  FileHandle.standardError.write(Data((message + "\n").utf8))
}
