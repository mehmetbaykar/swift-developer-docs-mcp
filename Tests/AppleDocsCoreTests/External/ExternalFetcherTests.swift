import Foundation
import Testing

@testable import AppleDocsCore

@Suite("ExternalFetcher")
struct ExternalFetcherTests {

  @Suite("Base Path Extraction")
  struct BasePathExtraction {
    @Test("Extracts empty base path for root documentation")
    func rootDocumentation() throws {
      let url = URL(string: "https://example.com/documentation/MyLib/MyType")!
      let basePath = try ExternalFetcher.extractExternalDocumentationBasePath(url)
      #expect(basePath == "")
    }

    @Test("Extracts base path with prefix")
    func prefixedDocumentation() throws {
      let url = URL(string: "https://example.com/api/v1/documentation/MyLib/MyType")!
      let basePath = try ExternalFetcher.extractExternalDocumentationBasePath(url)
      #expect(basePath == "/api/v1")
    }

    @Test("Handles trailing slashes")
    func trailingSlash() throws {
      let url = URL(string: "https://example.com/documentation/MyLib/")!
      let basePath = try ExternalFetcher.extractExternalDocumentationBasePath(url)
      #expect(basePath == "")
    }

    @Test("Rejects non-documentation URLs")
    func nonDocumentation() {
      let url = URL(string: "https://example.com/api/v1/something")!
      #expect(throws: AppleDocsError.self) {
        try ExternalFetcher.extractExternalDocumentationBasePath(url)
      }
    }
  }

  @Suite("JSON URL Construction")
  struct JSONURLConstruction {
    @Test("Builds JSON URL for documentation path")
    func standardPath() throws {
      let url = URL(string: "https://example.com/documentation/MyLib/MyType")!
      let jsonUrl = try ExternalFetcher.buildExternalDocCJsonUrl(url)
      #expect(jsonUrl.absoluteString == "https://example.com/data/documentation/MyLib/MyType.json")
    }

    @Test("Builds JSON URL with base path")
    func withBasePath() throws {
      let url = URL(string: "https://example.com/api/v1/documentation/MyLib/MyType")!
      let jsonUrl = try ExternalFetcher.buildExternalDocCJsonUrl(url)
      #expect(
        jsonUrl.absoluteString
          == "https://example.com/api/v1/data/documentation/MyLib/MyType.json")
    }

    @Test("Does not double .json extension")
    func alreadyJson() throws {
      let url = URL(string: "https://example.com/documentation/MyLib/MyType.json")!
      let jsonUrl = try ExternalFetcher.buildExternalDocCJsonUrl(url)
      #expect(jsonUrl.absoluteString == "https://example.com/data/documentation/MyLib/MyType.json")
    }
  }

  @Suite("User Agent")
  struct UserAgent {
    @Test("Uses expected user agent string")
    func userAgent() {
      #expect(ExternalFetcher.userAgent == "swift-developer-docs-mcp/1.0")
    }
  }
}
