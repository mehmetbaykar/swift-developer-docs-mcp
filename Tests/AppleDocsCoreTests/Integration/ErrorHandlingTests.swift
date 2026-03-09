import Foundation
import Testing

@testable import AppleDocsCore

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

  // MARK: - Error cases are distinct

  @Test("AppleDocsError cases are distinct")
  func errorCasesAreDistinct() {
    let errors: [AppleDocsError] = [
      .notFound,
      .invalidPath,
      .invalidURL("test"),
      .httpError(statusCode: 500, url: "https://example.com"),
      .decodingError(underlying: NSError(domain: "test", code: 0)),
      .insufficientContent,
      .networkError(underlying: NSError(domain: "test", code: 0)),
      .accessDenied,
      .robotsBlocked,
      .ssrfBlocked,
    ]

    // Each error should have a unique description
    let descriptions = errors.map { $0.localizedDescription }
    let uniqueDescriptions = Set(descriptions)
    #expect(uniqueDescriptions.count == errors.count)
  }

  // MARK: - Localized descriptions are human-readable

  @Test("AppleDocsError localized descriptions are human-readable")
  func localizedDescriptionsAreReadable() {
    #expect(AppleDocsError.notFound.localizedDescription == "Resource not found")
    #expect(
      AppleDocsError.invalidPath.localizedDescription
        == "Invalid path. Expected format: swift/array")
    #expect(AppleDocsError.invalidURL("bad-url").localizedDescription == "Invalid URL: bad-url")
    #expect(
      AppleDocsError.httpError(statusCode: 404, url: "https://example.com").localizedDescription
        == "HTTP 404 fetching https://example.com")
    #expect(
      AppleDocsError.insufficientContent.localizedDescription == "Insufficient content returned")
    #expect(AppleDocsError.accessDenied.localizedDescription == "Access denied")
    #expect(AppleDocsError.robotsBlocked.localizedDescription == "Blocked by robots.txt")
    #expect(AppleDocsError.ssrfBlocked.localizedDescription == "Request blocked: SSRF protection")
  }

  // MARK: - resolveFetchEndpoint: unsupported dev.apple.com paths

  @Test("resolveFetchEndpoint throws invalidURL for unsupported developer.apple.com paths")
  func resolveFetchEndpointUnsupportedApplePaths() {
    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("https://developer.apple.com/wwdc")
    }

    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("https://developer.apple.com/news/")
    }

    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("https://developer.apple.com/forums/thread/123")
    }
  }

  // MARK: - resolveFetchEndpoint: empty input

  @Test("resolveFetchEndpoint throws invalidPath for empty input")
  func resolveFetchEndpointEmptyInput() {
    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("")
    }

    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("   ")
    }
  }

  // MARK: - resolveFetchEndpoint: HTTP (non-HTTPS) URLs

  @Test("resolveFetchEndpoint throws invalidURL for HTTP URLs")
  func resolveFetchEndpointHTTPNotAllowed() {
    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("http://developer.apple.com/documentation/swift")
    }

    #expect(throws: AppleDocsError.self) {
      _ = try AppleDocsClient.resolveFetchEndpoint("http://example.com/docs")
    }
  }

  // MARK: - Error type discrimination with switch

  @Test("Error type discrimination via switch works correctly")
  func errorTypeDiscrimination() {
    let errors: [(AppleDocsError, String)] = [
      (.notFound, "notFound"),
      (.invalidPath, "invalidPath"),
      (.invalidURL("x"), "invalidURL"),
      (.httpError(statusCode: 500, url: "x"), "httpError"),
      (.decodingError(underlying: NSError(domain: "", code: 0)), "decodingError"),
      (.insufficientContent, "insufficientContent"),
      (.networkError(underlying: NSError(domain: "", code: 0)), "networkError"),
      (.accessDenied, "accessDenied"),
      (.robotsBlocked, "robotsBlocked"),
      (.ssrfBlocked, "ssrfBlocked"),
    ]

    for (error, expectedLabel) in errors {
      let label: String
      switch error {
      case .notFound: label = "notFound"
      case .invalidPath: label = "invalidPath"
      case .invalidURL: label = "invalidURL"
      case .httpError: label = "httpError"
      case .decodingError: label = "decodingError"
      case .insufficientContent: label = "insufficientContent"
      case .networkError: label = "networkError"
      case .accessDenied: label = "accessDenied"
      case .robotsBlocked: label = "robotsBlocked"
      case .ssrfBlocked: label = "ssrfBlocked"
      }
      #expect(label == expectedLabel)
    }
  }

  // MARK: - isNotFound convenience property

  @Test("AppleDocsError.isNotFound returns true only for .notFound")
  func isNotFoundProperty() {
    #expect(AppleDocsError.notFound.isNotFound == true)
    #expect(AppleDocsError.invalidPath.isNotFound == false)
    #expect(AppleDocsError.invalidURL("test").isNotFound == false)
    #expect(AppleDocsError.httpError(statusCode: 404, url: "x").isNotFound == false)
    #expect(AppleDocsError.accessDenied.isNotFound == false)
  }

  // MARK: - HIG path resolution via resolveFetchEndpoint

  @Test("Nested HIG page paths resolve correctly")
  func nestedHIGPathResolution() throws {
    let result = try AppleDocsClient.resolveFetchEndpoint(
      "design/human-interface-guidelines/foundations/color")
    #expect(result == "/design/human-interface-guidelines/foundations/color")

    let result2 = try AppleDocsClient.resolveFetchEndpoint(
      "/design/human-interface-guidelines/foundations/color")
    #expect(result2 == "/design/human-interface-guidelines/foundations/color")

    let result3 = try AppleDocsClient.resolveFetchEndpoint(
      "https://developer.apple.com/design/human-interface-guidelines/foundations/color")
    #expect(result3 == "/design/human-interface-guidelines/foundations/color")
  }

  // MARK: - Path normalization

  @Test("Path normalization during fetch endpoint resolution")
  func pathNormalization() throws {
    // Trailing slash on HIG path should be normalized
    let withTrailingSlash = try AppleDocsClient.resolveFetchEndpoint(
      "/design/human-interface-guidelines/getting-started/")
    #expect(withTrailingSlash == "/design/human-interface-guidelines/getting-started")

    // Documentation paths should be normalized
    let docPath = try AppleDocsClient.resolveFetchEndpoint("swift/array")
    #expect(docPath == "/documentation/swift/array")

    // Full URL documentation path preserved
    let fullURL = try AppleDocsClient.resolveFetchEndpoint(
      "https://developer.apple.com/documentation/swift/array")
    #expect(fullURL == "/documentation/swift/array")
  }

  // MARK: - resolveFetchEndpoint: valid paths

  @Test("resolveFetchEndpoint resolves valid documentation paths")
  func resolveFetchEndpointValidPaths() throws {
    let result = try AppleDocsClient.resolveFetchEndpoint("swift/array")
    #expect(result == "/documentation/swift/array")

    let result2 = try AppleDocsClient.resolveFetchEndpoint("/documentation/swift/string")
    #expect(result2 == "/documentation/swift/string")

    let result3 = try AppleDocsClient.resolveFetchEndpoint(
      "https://developer.apple.com/documentation/swiftui/view")
    #expect(result3 == "/documentation/swiftui/view")
  }

  // MARK: - resolveFetchEndpoint: external URLs

  @Test("resolveFetchEndpoint routes non-Apple URLs as external")
  func resolveFetchEndpointExternalURLs() throws {
    let result = try AppleDocsClient.resolveFetchEndpoint(
      "https://reference-ios.daily.co/documentation/daily")
    #expect(result.hasPrefix("/external/"))
    #expect(result.contains("reference-ios.daily.co"))
  }

  // MARK: - resolveFetchEndpoint: video paths

  @Test("resolveFetchEndpoint resolves video paths")
  func resolveFetchEndpointVideoPaths() throws {
    let result = try AppleDocsClient.resolveFetchEndpoint("videos/play/wwdc2024/10001")
    #expect(result == "/videos/play/wwdc2024/10001")

    let result2 = try AppleDocsClient.resolveFetchEndpoint("/videos/play/wwdc2023/10002")
    #expect(result2 == "/videos/play/wwdc2023/10002")
  }

  // MARK: - resolveFetchEndpoint: HIG table of contents path

  @Test("resolveFetchEndpoint resolves HIG table of contents path")
  func resolveFetchEndpointHIGTOC() throws {
    let result = try AppleDocsClient.resolveFetchEndpoint("design/human-interface-guidelines")
    #expect(result == "/design/human-interface-guidelines")
  }
}
