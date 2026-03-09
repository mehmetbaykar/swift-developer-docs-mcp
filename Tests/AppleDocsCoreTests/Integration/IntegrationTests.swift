import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Integration Tests")
struct IntegrationTests {

  private var isEnabled: Bool {
    ProcessInfo.processInfo.environment["INTEGRATION_TESTS"] == "1"
  }

  @Test("Search for 'swift' returns results")
  func searchSwift() async throws {
    guard isEnabled else { return }

    let result = try await AppleDocsActions.search(query: "swift")
    #expect(!result.formatted.contains("No results found"))
    #expect(result.formatted.contains("results for"))
    #expect(!result.json.isEmpty)
  }

  @Test("Fetch 'swift/array' returns markdown")
  func fetchSwiftArray() async throws {
    guard isEnabled else { return }

    let markdown = try await AppleDocsActions.fetch(path: "swift/array")
    #expect(markdown.contains("Array"))
    #expect(markdown.count >= DocumentRenderer.minContentLength)
  }

  @Test("Fetch HIG table of contents returns markdown")
  func fetchHIGTableOfContents() async throws {
    guard isEnabled else { return }

    let markdown = try await AppleDocsActions.fetchHIGTableOfContents()
    #expect(markdown.contains("Human Interface Guidelines"))
    #expect(markdown.count > 100)
  }

  @Test("Unified fetch routes documentation path correctly")
  func unifiedFetchDocumentation() async throws {
    guard isEnabled else { return }

    let client = AppleDocsClient.live
    let markdown = try await client.unifiedFetch(input: "swift/array")
    #expect(markdown.contains("Array"))
  }

  @Test("Unified fetch routes HIG path correctly")
  func unifiedFetchHIG() async throws {
    guard isEnabled else { return }

    let client = AppleDocsClient.live
    let markdown = try await client.unifiedFetch(
      input: "design/human-interface-guidelines")
    #expect(markdown.contains("Human Interface Guidelines"))
  }

  @Test("Search returns valid JSON")
  func searchReturnsJSON() async throws {
    guard isEnabled else { return }

    let result = try await AppleDocsActions.search(query: "SwiftUI View")
    #expect(result.json.contains("results"))
  }
}
