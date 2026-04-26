import Foundation

struct ServeCommand: CLICommand {
  let name = "serve"
  let usage = "serve [--port PORT] [--host HOST] — Start the HTTP server"

  func run(arguments: [String]) async throws {
    var port = 8080
    var hostname = "127.0.0.1"

    var i = 0
    while i < arguments.count {
      switch arguments[i] {
      case "--port":
        if i + 1 < arguments.count, let p = Int(arguments[i + 1]) {
          port = p
          i += 2
        } else {
          printToStdErr("Error: --port requires a valid integer")
          Foundation.exit(1)
        }
      case "--host":
        if i + 1 < arguments.count {
          hostname = arguments[i + 1]
          i += 2
        } else {
          printToStdErr("Error: --host requires a value")
          Foundation.exit(1)
        }
      default:
        if arguments[i].hasPrefix("--") {
          printToStdErr("Error: unknown option \(arguments[i])")
          printToStdErr("Usage: \(usage)")
          Foundation.exit(1)
        }
        printToStdErr("Error: unexpected argument \(arguments[i])")
        printToStdErr("Usage: \(usage)")
        Foundation.exit(1)
      }
    }

    let server = ServerApp(hostname: hostname, port: port)
    try await server.run()
  }
}
