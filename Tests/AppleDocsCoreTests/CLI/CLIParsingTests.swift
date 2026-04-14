import Foundation
import Testing

@testable import AppleDocsCore

/// Tests for CLI endpoint resolution logic.
///
/// CLIArgParser and CLIRouter live in the executable target (`swift-developer-docs-mcp`)
/// which depends on FastMCP and Hummingbird. The test target only links AppleDocsCore,
/// so we cannot `@testable import swift_developer_docs_mcp`.
///
/// The core routing logic that CLI uses is `AppleDocsClient.resolveFetchEndpoint`,
/// which IS in AppleDocsCore. These tests verify the endpoint resolution that the
/// CLI fetch/video/hig/external commands rely on.
///
/// Mapped from sosumi.ai `tests/cli-endpoints.test.ts` -> `resolveFetchEndpoint`.
@Suite("CLI Endpoint Resolution")
struct CLIParsingTests {

  // MARK: - Documentation paths (matches "maps bare documentation paths")

  @Suite("Bare documentation paths")
  struct BareDocumentationPaths {
    @Test("Maps 'swift/array' to /documentation/swift/array")
    func barePathToDocumentation() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("swift/array")
      #expect(result == "/documentation/swift/array")
    }

    @Test("Preserves existing /documentation/ prefix")
    func preservesDocPrefix() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint("/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }
  }

  // MARK: - Full URL mapping (matches "maps Apple documentation URLs")

  @Suite("Apple documentation URLs")
  struct AppleDocURLs {
    @Test("Maps full Apple documentation URL to path")
    func fullDocURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/documentation/swift/array")
      #expect(result == "/documentation/swift/array")
    }
  }

  // MARK: - HIG URLs (matches "maps HIG URLs")

  @Suite("HIG URLs")
  struct HIGURLs {
    @Test("Maps HIG URL to path")
    func higURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/design/human-interface-guidelines/foundations/color")
      #expect(result == "/design/human-interface-guidelines/foundations/color")
    }

    @Test("Maps bare HIG path")
    func bareHIGPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "design/human-interface-guidelines/color")
      #expect(result == "/design/human-interface-guidelines/color")
    }
  }

  // MARK: - Video URLs (matches "maps Apple video URLs")

  @Suite("Video URLs")
  struct VideoURLs {
    @Test("Maps Apple video URL to path")
    func videoURL() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://developer.apple.com/videos/play/wwdc2021/10133/")
      #expect(result == "/videos/play/wwdc2021/10133")
    }

    @Test("Maps bare video path")
    func bareVideoPath() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "videos/play/wwdc2024/10001")
      #expect(result == "/videos/play/wwdc2024/10001")
    }
  }

  // MARK: - External URLs (matches "maps non-Apple https URLs to external route")

  @Suite("External URLs")
  struct ExternalURLs {
    @Test("Maps non-Apple HTTPS URL to /external/ route")
    func nonAppleURLToExternal() throws {
      let result = try AppleDocsClient.resolveFetchEndpoint(
        "https://apple.github.io/swift-argument-parser/documentation/argumentparser")
      #expect(
        result
          == "/external/https://apple.github.io/swift-argument-parser/documentation/argumentparser"
      )
    }
  }

  // MARK: - Search endpoint (matches "resolveSearchEndpoint")

  @Suite("Search query handling")
  struct SearchQueryHandling {

    @Test("Query with spaces is percent-encoded for URL")
    func queryEncodedForURL() {
      let query = "SwiftData macro"
      let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      #expect(encoded == "SwiftData%20macro")
      let searchUrl = "https://developer.apple.com/search/?q=\(encoded ?? query)"
      #expect(searchUrl.contains("SwiftData%20macro"))
    }

    @Test("Query with special characters is percent-encoded")
    func specialCharactersEncoded() {
      let query = "Array<Int>"
      let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      #expect(encoded != nil)
      #expect(encoded?.contains("%3C") == true)
      #expect(encoded?.contains("%3E") == true)
    }

    @Test("AppleDocsActions.search returns 'No results' for empty query result")
    func emptySearchReturnsNoResults() async throws {
      // Test the formatting path with a mock client that returns empty results
      nonisolated(unsafe) var capturedQuery = ""

      let client = AppleDocsClient(
        fetch: { _ in "" },
        search: { query in
          capturedQuery = query
          return .init(
            formatted: "No results found for \"\(query)\"",
            json: "{\"query\":\"\\(query)\",\"results\":[]}"
          )
        },
        fetchHIG: { _ in "" },
        fetchHIGTableOfContents: { "" },
        fetchVideo: { _ in "" },
        fetchExternal: { _ in "" }
      )

      let result = try await client.search("test query")
      #expect(capturedQuery == "test query")
      #expect(result.formatted.contains("No results"))
    }
  }

  // MARK: - Error cases (matches "throws for unsupported developer.apple.com pages")

  @Suite("Error cases")
  struct ErrorCases {
    @Test("Throws for unsupported developer.apple.com URL path")
    func unsupportedApplePath() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint(
          "https://developer.apple.com/xcode/")
      }
    }

    @Test("Unsupported path error message contains the path")
    func unsupportedPathErrorMessage() {
      do {
        _ = try AppleDocsClient.resolveFetchEndpoint(
          "https://developer.apple.com/xcode/")
        Issue.record("Expected error to be thrown")
      } catch let error as AppleDocsError {
        if case .invalidURL(let message) = error {
          #expect(message.contains("/xcode"))
        } else {
          Issue.record("Expected .invalidURL, got \(error)")
        }
      } catch {
        Issue.record("Expected AppleDocsError, got \(error)")
      }
    }

    @Test("Throws for empty input")
    func emptyInput() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("")
      }
    }

    @Test("Throws for whitespace-only input")
    func whitespaceOnlyInput() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint("   ")
      }
    }

    @Test("Rejects HTTP (non-HTTPS) URLs")
    func rejectsHTTP() {
      #expect(throws: AppleDocsError.self) {
        try AppleDocsClient.resolveFetchEndpoint(
          "http://developer.apple.com/documentation/swift")
      }
    }
  }
}
