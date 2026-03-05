import Foundation

protocol CLICommand {
  var name: String { get }
  var usage: String { get }
  func run(arguments: [String]) async throws
}
