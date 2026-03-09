import Foundation
import Testing

@testable import AppleDocsCore

@Suite("ReferenceFetcher Tests")
struct ReferenceFetcherTests {

  // MARK: - Fixture-based rendering

  @Suite("Fixture Rendering")
  struct FixtureRendering {
    private func loadArrayFixture() throws -> AppleDocJSON {
      let fixtureURL = Bundle.module.url(
        forResource: "array", withExtension: "json", subdirectory: "Fixtures")!
      let data = try Data(contentsOf: fixtureURL)
      return try JSONDecoder().decode(AppleDocJSON.self, from: data)
    }

    @Test("Array fixture decodes successfully")
    func arrayFixtureDecodes() throws {
      let json = try loadArrayFixture()
      #expect(json.metadata?.title == "Array")
      #expect(json.kind == "symbol")
    }

    @Test("Array fixture has topic sections")
    func arrayFixtureHasTopics() throws {
      let json = try loadArrayFixture()
      #expect(json.topicSections != nil)
      #expect(json.topicSections!.count > 0)
    }

    @Test("Array fixture renders to markdown with title")
    func arrayFixtureRendersTitle() throws {
      let json = try loadArrayFixture()
      let markdown = DocumentRenderer.renderFromJSON(
        json, sourceURL: "https://developer.apple.com/documentation/swift/array")
      #expect(markdown.contains("# Array"))
    }

    @Test("Array fixture renders abstract")
    func arrayFixtureRendersAbstract() throws {
      let json = try loadArrayFixture()
      let markdown = DocumentRenderer.renderFromJSON(
        json, sourceURL: "https://developer.apple.com/documentation/swift/array")
      #expect(markdown.contains("An ordered, random-access collection."))
    }

    @Test("Array fixture renders topic section titles")
    func arrayFixtureRendersTopicSections() throws {
      let json = try loadArrayFixture()
      let markdown = DocumentRenderer.renderFromJSON(
        json, sourceURL: "https://developer.apple.com/documentation/swift/array")
      #expect(markdown.contains("Creating an Array"))
      #expect(markdown.contains("Inspecting an Array"))
      #expect(markdown.contains("Accessing Elements"))
    }

    @Test("Rendered markdown exceeds minimum content length")
    func markdownExceedsMinLength() throws {
      let json = try loadArrayFixture()
      let markdown = DocumentRenderer.renderFromJSON(
        json, sourceURL: "https://developer.apple.com/documentation/swift/array")
      #expect(markdown.count >= DocumentRenderer.minContentLength)
    }
  }

  // MARK: - AppleDocsClient endpoint resolution

  @Suite("Endpoint Resolution")
  struct EndpointResolution {
    @Test("Resolves documentation path")
    func documentationPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("swift/array")
      #expect(result == "/documentation/swift/array")
    }

    @Test("Resolves full documentation URL")
    func documentationURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }

    @Test("Resolves HIG path")
    func higPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "design/human-interface-guidelines")
      #expect(result == "/design/human-interface-guidelines")
    }

    @Test("Resolves HIG subpath")
    func higSubpath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "design/human-interface-guidelines/color")
      #expect(result == "/design/human-interface-guidelines/color")
    }

    @Test("Resolves video path")
    func videoPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "videos/play/wwdc2024/10001")
      #expect(result == "/videos/play/wwdc2024/10001")
    }

    @Test("Resolves external URL")
    func externalURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://docs.swift.org/documentation/MyLib")
      #expect(result == "/external/https://docs.swift.org/documentation/MyLib")
    }

    @Test("Throws for empty input")
    func emptyInput() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("")
      }
    }

    @Test("Throws for http URL")
    func httpURL() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("http://developer.apple.com/documentation/swift")
      }
    }
  }

  // MARK: - Fetcher structure

  @Suite("Fetcher")
  struct FetcherTests {
    @Test("Mock fetcher returns custom data")
    func mockFetcher() async throws {
      let mockJSON = AppleDocJSON(
        metadata: DocumentationMetadata(title: "MockDoc"),
        kind: "symbol"
      )
      let fetcher = Fetcher(
        fetchJSON: { _ in mockJSON },
        fetchHTML: { _ in "<html></html>" }
      )
      let result = try await fetcher.fetchJSON("test")
      #expect(result.metadata?.title == "MockDoc")
    }

    @Test("Mock fetcher HTML returns custom data")
    func mockFetcherHTML() async throws {
      let fetcher = Fetcher(
        fetchJSON: { _ in AppleDocJSON() },
        fetchHTML: { _ in "<html><body>Test</body></html>" }
      )
      let result = try await fetcher.fetchHTML(URL(string: "https://example.com")!)
      #expect(result.contains("Test"))
    }
  }
}
