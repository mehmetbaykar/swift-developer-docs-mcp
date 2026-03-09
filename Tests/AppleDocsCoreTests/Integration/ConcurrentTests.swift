import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Concurrent Request Tests")
struct ConcurrentTests {

  @Test("Multiple concurrent resolveFetchEndpoint calls don't interfere")
  func concurrentResolveFetchEndpoint() async throws {
    let paths = [
      "swift/array",
      "swift/string",
      "swift/dictionary",
      "swiftui/view",
      "swiftui/text",
      "foundation/url",
      "foundation/data",
      "uikit/uiview",
      "uikit/uiviewcontroller",
      "combine/publisher",
    ]

    try await withThrowingTaskGroup(of: (String, String).self) { group in
      for path in paths {
        group.addTask {
          let result = try AppleDocsClient.resolveFetchEndpoint(path)
          return (path, result)
        }
      }

      var results: [String: String] = [:]
      for try await (input, output) in group {
        results[input] = output
      }

      #expect(results.count == paths.count)

      for path in paths {
        let expected = "/documentation/\(path)"
        #expect(results[path] == expected)
      }
    }
  }

  @Test("AppleDocsClient struct is Sendable")
  func clientIsSendable() async {
    let client = AppleDocsClient.live
    // Compile-time check: assigning to a let in a Task proves Sendable
    let _: AppleDocsClient = await Task {
      return client
    }.value
  }

  @Test("Fetcher struct is Sendable")
  func fetcherIsSendable() async {
    let fetcher = Fetcher.live
    // Compile-time check: assigning to a let in a Task proves Sendable
    let _: Fetcher = await Task {
      return fetcher
    }.value
  }

  @Test("Concurrent resolveFetchEndpoint with mixed path types")
  func concurrentMixedPaths() async throws {
    let inputs = [
      "swift/array",
      "/documentation/swift/string",
      "https://developer.apple.com/documentation/swiftui/view",
      "design/human-interface-guidelines",
      "design/human-interface-guidelines/foundations/color",
      "videos/play/wwdc2024/10001",
      "https://reference-ios.daily.co/documentation/daily",
    ]

    try await withThrowingTaskGroup(of: String.self) { group in
      for input in inputs {
        group.addTask {
          return try AppleDocsClient.resolveFetchEndpoint(input)
        }
      }

      var results: [String] = []
      for try await result in group {
        results.append(result)
      }

      #expect(results.count == inputs.count)
    }
  }

  @Test("Fetcher dependency injection works with custom implementation")
  func fetcherDependencyInjection() async throws {
    let customFetcher = Fetcher(
      fetchJSON: { path in
        throw AppleDocsError.notFound
      },
      fetchHTML: { url in
        throw AppleDocsError.notFound
      }
    )

    // Custom fetcher should throw our specific error
    await #expect(throws: AppleDocsError.self) {
      _ = try await customFetcher.fetchJSON("swift/array")
    }

    await #expect(throws: AppleDocsError.self) {
      _ = try await customFetcher.fetchHTML(URL(string: "https://example.com")!)
    }
  }
}
